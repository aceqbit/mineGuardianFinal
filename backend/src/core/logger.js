import pino from 'pino';

const dev = process.env.NODE_ENV === 'development' || process.env.NODE_ENV === undefined;

export const logger = pino({
  level: process.env.LOG_LEVEL || (process.env.NODE_ENV === 'test' ? 'silent' : 'info'),
  redact: ['req.headers.authorization', 'token', 'password', '*.token', '*.password'],
  ...(dev
    ? { transport: { target: 'pino-pretty', options: { colorize: true, translateTime: 'HH:MM:ss' } } }
    : {}),
});

/** +919876500101 -> +91******0101 */
export function maskPhone(e164) {
  if (!e164 || typeof e164 !== 'string') return '';
  const s = e164.trim();
  if (s.length <= 4) return '*'.repeat(s.length);
  const dial = s.startsWith('+') ? s.slice(0, Math.min(3, s.length - 4)) : '';
  const tail = s.slice(-4);
  const stars = '*'.repeat(Math.max(0, s.length - dial.length - 4));
  return `${dial}${stars}${tail}`;
}
