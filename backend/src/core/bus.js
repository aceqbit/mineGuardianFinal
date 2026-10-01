import { EventEmitter } from 'node:events';
import { v4 as uuid } from 'uuid';
import { BUS_EVENTS } from '../contracts/events.js';
import { logger } from './logger.js';

const emitter = new EventEmitter();
emitter.setMaxListeners(100);

/** publish(name, data) throws on unknown bus event names. */
export function publish(name, data = {}) {
  if (!BUS_EVENTS.includes(name)) {
    throw new Error(`Unknown bus event: ${name}`);
  }
  const envelope = { v: 1, id: uuid(), ts: new Date().toISOString(), name, data };
  emitter.emit(name, envelope);
  return envelope;
}

/** subscribe(name, handler) – handler receives the envelope; runs async, errors isolated. */
export function subscribe(name, handler) {
  if (!BUS_EVENTS.includes(name)) {
    throw new Error(`Unknown bus event: ${name}`);
  }
  const wrapped = (envelope) => {
    setImmediate(async () => {
      try {
        await handler(envelope);
      } catch (err) {
        logger.error({ err, event: name }, 'bus handler failed');
      }
    });
  };
  emitter.on(name, wrapped);
  return () => emitter.off(name, wrapped);
}

export const bus = { publish, subscribe };
export default bus;
