/** Shared schema options: timestamps + toJSON with id virtual and no __v. */
export function applyCommon(schema) {
  schema.set('toJSON', {
    virtuals: true,
    versionKey: false,
    transform: (_doc, ret) => {
      delete ret.__v;
      return ret;
    },
  });
  schema.set('toObject', { virtuals: true });
  return schema;
}

export const pointSchemaDef = {
  type: { type: String, enum: ['Point'], default: 'Point' },
  coordinates: { type: [Number], default: undefined },
};
