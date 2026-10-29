package dev.nyxveravisuals.event;

/** Events implementing this stop propagating to normal listeners once cancelled. */
public interface Cancellable {
	boolean isCancelled();

	void cancel();
}
