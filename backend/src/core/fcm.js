import mongoose from 'mongoose';
import { firebaseMessaging } from './firebase.js';
import { logger } from './logger.js';

const BAD = new Set(['messaging/registration-token-not-registered', 'messaging/invalid-registration-token', 'messaging/invalid-argument']);

/** Send a push to every token of a user; prune dead tokens. Never throws. */
export async function sendToUser(userId, { title, body, data = {} }) {
  try {
    const User = mongoose.model('User');
    const u = await User.findById(userId).select('fcmTokens');
    const tokens = u?.fcmTokens ?? [];
    if (!tokens.length) return { sent: 0 };
    const stringData = Object.fromEntries(Object.entries(data).map(([k, v]) => [k, String(v)]));
    const res = await firebaseMessaging().sendEachForMulticast({ tokens, notification: { title, body }, data: stringData });
    const dead = [];
    res.responses.forEach((r, i) => {
      if (!r.success && BAD.has(r.error?.code)) dead.push(tokens[i]);
    });
    if (dead.length) await User.updateOne({ _id: userId }, { $pull: { fcmTokens: { $in: dead } } });
    return { sent: res.successCount, failed: res.failureCount };
  } catch (err) {
    logger.warn({ err: err.message }, 'fcm send failed');
    return { sent: 0, error: err.message };
  }
}

export async function sendToUsers(userIds, payload) {
  return Promise.allSettled([...new Set(userIds.map(String))].map((id) => sendToUser(id, payload)));
}
