import fs from 'node:fs';
import path from 'node:path';
import admin from 'firebase-admin';
import { env } from '../config/env.js';
import { logger } from './logger.js';

let app;

export function getFirebaseApp() {
  if (app) return app;
  const credPath = path.resolve(process.cwd(), env.GOOGLE_APPLICATION_CREDENTIALS);
  const opts = { projectId: env.FIREBASE_PROJECT_ID, ...(env.FIREBASE_STORAGE_BUCKET ? { storageBucket: env.FIREBASE_STORAGE_BUCKET } : {}) };
  if (fs.existsSync(credPath)) {
    opts.credential = admin.credential.cert(JSON.parse(fs.readFileSync(credPath, 'utf8')));
  } else {
    logger.warn(`Firebase service account not found at ${credPath}; using application default credentials`);
    opts.credential = admin.credential.applicationDefault();
  }
  app = admin.initializeApp(opts);
  return app;
}

export const firebaseAuth = () => getFirebaseApp().auth();
export const firebaseStorage = () => getFirebaseApp().storage();
export const firebaseMessaging = () => getFirebaseApp().messaging();
