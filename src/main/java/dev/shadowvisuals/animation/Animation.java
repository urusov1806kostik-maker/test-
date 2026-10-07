package dev.shadowvisuals.animation;

/**
 * Time-based tween. The value is computed lazily from the clock, so it needs no per-frame update, and
 * retargeting mid-flight starts from the current value (no jumps).
 */
public final class Animation {
	private final AnimationClock clock;
	private final float duration;
	private final Easing easing;
	private float from;
	private float to;
	private double startTime;

	public Animation(float initial, float durationSeconds, Easing easing) {
		this(AnimationClock.global(), initial, durationSeconds, easing);
	}

	public Animation(AnimationClock clock, float initial, float durationSeconds, Easing easing) {
		this.clock = clock;
		this.duration = durationSeconds;
		this.easing = easing;
		this.from = initial;
		this.to = initial;
		this.startTime = clock.now();
	}

	public void animateTo(float target) {
		if (target == to) {
			return;
		}
		from = value();
		to = target;
		startTime = clock.now();
	}

	/** Jumps to {@code target} without animating. */
	public void snapTo(float target) {
		from = target;
		to = target;
		startTime = clock.now();
	}

	public float value() {
		float scaled = clock.scaleDuration(duration);
		if (scaled <= 0f) {
			return to;
		}
		float t = (float) ((clock.now() - startTime) / scaled);
		if (t >= 1f) {
			return to;
		}
		if (t <= 0f) {
			return from;
		}
		return from + (to - from) * easing.ease(t);
	}

	public float target() {
		return to;
	}

	public boolean isRunning() {
		float scaled = clock.scaleDuration(duration);
		return scaled > 0f && clock.now() - startTime < scaled && from != to;
	}

	/** True once the animation reached {@code 0} and is no longer moving (e.g. safe to remove an element). */
	public boolean isFinishedAtZero() {
		return to == 0f && !isRunning();
	}
}
