package dev.nyxveravisuals.event.events;

import dev.nyxveravisuals.event.Cancellable;

/** In-game mouse wheel input while no screen is open; cancelling stops the hotbar from scrolling. */
public final class MouseScrollEvent implements Cancellable {
	private final double horizontal;
	private final double vertical;
	private boolean cancelled;

	public MouseScrollEvent(double horizontal, double vertical) {
		this.horizontal = horizontal;
		this.vertical = vertical;
	}

	public double horizontal() {
		return horizontal;
	}

	public double vertical() {
		return vertical;
	}

	@Override
	public boolean isCancelled() {
		return cancelled;
	}

	@Override
	public void cancel() {
		cancelled = true;
	}
}
