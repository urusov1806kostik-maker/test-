package dev.nyxveravisuals.render;

/** Per-frame bookkeeping shared by renderers (frame index for once-per-frame caches). */
public final class FrameState {
	private long frameIndex;

	public void beginFrame() {
		frameIndex++;
	}

	public long frameIndex() {
		return frameIndex;
	}
}
