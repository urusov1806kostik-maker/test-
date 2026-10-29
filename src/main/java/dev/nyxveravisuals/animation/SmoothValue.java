package dev.nyxveravisuals.animation;

import dev.nyxveravisuals.util.MathUtil;

/**
 * Continuously follows a moving target with frame-rate independent exponential smoothing. Used for values
 * that change often (health bars, counters, positions) where restarting a tween each change would stutter.
 */
public final class SmoothValue {
	private final AnimationClock clock;
	private final float speed;
	private float value;
	private float target;
	private double lastSample;

	/** @param speed convergence rate per second; ~12 feels responsive, ~6 feels soft */
	public SmoothValue(float initial, float speed) {
		this(AnimationClock.global(), initial, speed);
	}

	public SmoothValue(AnimationClock clock, float initial, float speed) {
		this.clock = clock;
		this.speed = speed;
		this.value = initial;
		this.target = initial;
		this.lastSample = clock.now();
	}

	public void setTarget(float target) {
		this.target = target;
	}

	public void snap(float target) {
		this.target = target;
		this.value = target;
	}

	public float target() {
		return target;
	}

	/** Advances by the time elapsed since the previous call and returns the current value. */
	public float get() {
		double now = clock.now();
		float delta = (float) Math.min(0.1, Math.max(0.0, now - lastSample));
		lastSample = now;
		float scale = clock.mode().durationScale();
		if (scale <= 0f) {
			value = target;
		} else {
			value = MathUtil.approach(value, target, speed / scale, delta);
		}
		return value;
	}
}
