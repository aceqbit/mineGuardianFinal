import mongoose from 'mongoose';
import { logger } from './logger.js';

mongoose.set('strictQuery', true);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export async function connectDb(uri, { attempts = 5, delayMs = 2000 } = {}) {
  let lastErr;
  for (let i = 1; i <= attempts; i++) {
    try {
      await mongoose.connect(uri, { dbName: process.env.MONGODB_DB || 'mine_guardian', serverSelectionTimeoutMS: 8000 });
      logger.info('Mongo connected');
      return mongoose.connection;
    } catch (err) {
      lastErr = err;
      logger.warn(`Mongo connect attempt ${i}/${attempts} failed: ${err.message}`);
      if (i < attempts) await sleep(delayMs);
    }
  }
  throw lastErr;
}

export const disconnectDb = () => mongoose.disconnect();
export { mongoose };
