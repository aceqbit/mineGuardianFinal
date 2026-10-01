// Server-side photo quality + integrity thresholds. These scales differ from the phone's: calibrate with the same 10 photos.
export const SERVER_BLUR_MIN = 40;
export const BRIGHTNESS_MIN = 40;
export const BRIGHTNESS_MAX = 220;
export const MIN_SIDE_PX = 720;

export const STALE_AFTER_MS = 15 * 60 * 1000;
export const OFFLINE_DELAYED_MS = 2 * 60 * 1000;
export const CLOCK_SKEW_MAX_SEC = 300;
export const LOW_ACCURACY_M = 100;
export const SHIFT_TOLERANCE_MIN = 30;

export const MAX_UPLOAD_BYTES = 8 * 1024 * 1024;
export const UPLOADS_PER_MINUTE = 10;
