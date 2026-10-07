package dev.shadowvisuals.animation;

/** Easing curves mapping linear progress {@code t in [0, 1]} to eased progress. */
public enum Easing {
	LINEAR {
		@Override
		public float apply(float t) {
			return t;
		}
	},
	EASE_OUT_QUAD {
		@Override
		public float apply(float t) {
			return 1 - (1 - t) * (1 - t);
		}
	},
	EASE_IN_OUT_QUAD {
		@Override
		public float apply(float t) {
			return t < 0.5f ? 2 * t * t : 1 - (float) Math.pow(-2 * t + 2, 2) / 2;
		}
	},
	EASE_OUT_CUBIC {
		@Override
		public float apply(float t) {
			float inv = 1 - t;
			return 1 - inv * inv * inv;
		}
	},
	EASE_IN_OUT_CUBIC {
		@Override
		public float apply(float t) {
			return t < 0.5f ? 4 * t * t * t : 1 - (float) Math.pow(-2 * t + 2, 3) / 2;
		}
	},
	EASE_OUT_QUINT {
		@Override
		public float apply(float t) {
			return 1 - (float) Math.pow(1 - t, 5);
		}
	},
	EASE_OUT_EXPO {
		@Override
		public float apply(float t) {
			return t >= 1 ? 1 : 1 - (float) Math.pow(2, -10 * t);
		}
	},
	/** Slight overshoot; used for small "pop" feedback (toggles, notifications). */
	EASE_OUT_BACK {
		@Override
		public float apply(float t) {
			float c1 = 1.20158f;
			float c3 = c1 + 1;
			float x = t - 1;
			return 1 + c3 * x * x * x + c1 * x * x;
		}
	};

	public abstract float apply(float t);

	public final float ease(float t) {
		if (t <= 0f) {
			return 0f;
		}
		if (t >= 1f) {
			return 1f;
		}
		return apply(t);
	}
}
