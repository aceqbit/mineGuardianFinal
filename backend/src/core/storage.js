import crypto from 'node:crypto';
import fs from 'node:fs/promises';
import nodePath from 'node:path';
import { env } from '../config/env.js';
import { firebaseStorage } from './firebase.js';

// STORAGE_DRIVER=firebase (default) uses Firebase Storage. STORAGE_DRIVER=local keeps files on this machine
// (no billing account needed) and serves them through short-lived signed links at /files/<token>.

const bucket = () => firebaseStorage().bucket();
const local = () => env.STORAGE_DRIVER === 'local';

/** Resolve a storage path inside `root`; refuses anything that escapes it. */
export function safeJoin(root, p) {
  const base = nodePath.resolve(root);
  const full = nodePath.resolve(base, p);
  if (full !== base && !full.startsWith(base + nodePath.sep)) throw new Error('Invalid storage path');
  return full;
}

const secret = (key) => crypto.createHash('sha256').update(`${key}|mg-files`).digest();
const b64 = (s) => Buffer.from(s).toString('base64url');

/** token = base64url(path).expiresMs.hmac */
export function signToken(p, expiresMs, key) {
  const body = `${b64(p)}.${expiresMs}`;
  return `${body}.${crypto.createHmac('sha256', secret(key)).update(body).digest('base64url')}`;
}

/** Returns the storage path for a valid, unexpired token, else null. */
export function verifyToken(token, key, now = Date.now()) {
  const [pathPart, exp, sig] = String(token).split('.');
  if (!pathPart || !exp || !sig) return null;
  const good = crypto.createHmac('sha256', secret(key)).update(`${pathPart}.${exp}`).digest('base64url');
  const a = Buffer.from(sig);
  const b = Buffer.from(good);
  if (a.length !== b.length || !crypto.timingSafeEqual(a, b)) return null;
  if (Number(exp) < now) return null;
  return Buffer.from(pathPart, 'base64url').toString();
}

const tokenKey = () => env.MONGODB_URI ?? 'dev';
const root = () => env.LOCAL_STORAGE_DIR;

export async function uploadBuffer(path, buffer, contentType = 'image/jpeg') {
  if (local()) {
    const full = safeJoin(root(), path);
    await fs.mkdir(nodePath.dirname(full), { recursive: true });
    await fs.writeFile(full, buffer);
    return path;
  }
  await bucket().file(path).save(buffer, { contentType, resumable: false });
  return path;
}

/** Signed read URL, default 15 minutes. */
export async function signedUrl(path, minutes = 15) {
  if (!path) return null;
  if (local()) return `${env.PUBLIC_BASE_URL}/files/${signToken(path, Date.now() + minutes * 60_000, tokenKey())}`;
  const [url] = await bucket().file(path).getSignedUrl({ action: 'read', expires: Date.now() + minutes * 60 * 1000 });
  return url;
}

export async function download(path) {
  if (local()) return fs.readFile(safeJoin(root(), path));
  const [buf] = await bucket().file(path).download();
  return buf;
}

export async function exists(path) {
  if (local()) {
    try {
      await fs.access(safeJoin(root(), path));
      return true;
    } catch {
      return false;
    }
  }
  const [ok] = await bucket().file(path).exists();
  return ok;
}

/** For the /files route (local driver only). */
export function resolveLocalToken(token) {
  const p = verifyToken(token, tokenKey());
  return p ? { path: p, file: safeJoin(root(), p) } : null;
}
