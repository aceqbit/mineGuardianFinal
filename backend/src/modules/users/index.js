import { Router } from 'express';
import { authenticate } from '../../core/auth.js';
import { asyncHandler } from '../../core/errors.js';
import { validate } from '../../core/validate.js';
import { User } from '../../models/User.js';
import { fcmTokenSchema } from '../auth/auth.schemas.js';

const router = Router();

router.put(
  '/me/fcm-token',
  authenticate(),
  validate({ body: fcmTokenSchema }),
  asyncHandler(async (req, res) => {
    const { token } = req.body;
    await User.updateOne({ _id: req.user._id }, { $pull: { fcmTokens: token } });
    await User.updateOne({ _id: req.user._id }, { $push: { fcmTokens: { $each: [token], $slice: -5 } } });
    res.json({ ok: true });
  }),
);

export default { name: 'users', basePath: '/api/users', router };
