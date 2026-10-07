package dev.shadowvisuals.event;

/** Listener order; lower ordinal runs first. {@link #MONITOR} observes the final outcome, even if cancelled. */
public enum Priority {
	HIGHEST,
	HIGH,
	NORMAL,
	LOW,
	LOWEST,
	MONITOR;

	boolean receivesCancelled() {
		return this == MONITOR;
	}
}
