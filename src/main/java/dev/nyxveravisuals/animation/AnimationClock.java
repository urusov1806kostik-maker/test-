package dev.nyxveravisuals.animation;

import java.util.function.LongSupplier;

/**
 * Frame time source for every animation. {@link #frame()} is called once per rendered frame; animations
 * read {@link #now()} and {@link #delta()} so their speed never depends on FPS. The accessibility mode
 * scales or disables durations globally.
 */
public final class AnimationClock {
	public enum Mode {
		FULL(1f),
		REDUCED(0.45f),
		OFF(0f);

		private final float durationScale;

		Mode(float durationScale) {
			this.durationScale = durationScale;
		}

		public float durationScale() {
			return durationScale;
		}
	}

	private static final float MAX_DELTA = 0.1f;
	private static final AnimationClock GLOBAL = new AnimationClock(System::nanoTime);

	private final LongSupplier nanoSource;
	private final long origin;
	private long lastFrame;
	private double now;
	private float delta;
	private Mode mode = Mode.FULL;

	public AnimationClock(LongSupplier nanoSource) {
		this.nanoSource = nanoSource;
		this.origin = nanoSource.getAsLong();
		this.lastFrame = origin;
	}

	/** The render-thread clock shared by GUI, HUD and world visuals. */
	public static AnimationClock global() {
		return GLOBAL;
	}

	public void frame() {
		long time = nanoSource.getAsLong();
		delta = Math.min(MAX_DELTA, Math.max(0f, (time - lastFrame) / 1_000_000_000f));
		lastFrame = time;
		now = (time - origin) / 1_000_000_000.0;
	}

	/** Seconds since start, sampled at the last frame. */
	public double now() {
		return now;
	}

	/** Seconds elapsed since the previous frame, clamped to avoid jumps after stalls. */
	public float delta() {
		return delta;
	}

	public Mode mode() {
		return mode;
	}

	public void setMode(Mode mode) {
		this.mode = mode;
	}

	public float scaleDuration(float seconds) {
		return seconds * mode.durationScale();
	}
}
