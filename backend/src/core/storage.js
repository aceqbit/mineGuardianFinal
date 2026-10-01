import { firebaseStorage } from './firebase.js';

const bucket = () => firebaseStorage().bucket();

export async function uploadBuffer(path, buffer, contentType = 'image/jpeg') {
  await bucket().file(path).save(buffer, { contentType, resumable: false });
  return path;
}

/** Signed read URL, default 15 minutes. */
export async function signedUrl(path, minutes = 15) {
  if (!path) return null;
  const [url] = await bucket().file(path).getSignedUrl({ action: 'read', expires: Date.now() + minutes * 60 * 1000 });
  return url;
}

export async function download(path) {
  const [buf] = await bucket().file(path).download();
  return buf;
}

export async function exists(path) {
  const [ok] = await bucket().file(path).exists();
  return ok;
}
