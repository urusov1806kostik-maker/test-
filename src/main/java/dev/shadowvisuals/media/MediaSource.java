package dev.shadowvisuals.media;

/** Source of "what is playing right now". Implementations must be safe to poll from the client thread. */
public interface MediaSource extends AutoCloseable {
	enum Status {
		/** The operating system offers no supported media session API. */
		UNSUPPORTED,
		STARTING,
		RUNNING,
		/** The helper failed repeatedly; it is retried with growing delays. */
		FAILED
	}

	void start();

	Status status();

	/** Latest snapshot, or {@code null} when nothing is playing or no data arrived yet. */
	MediaInfo current();

	@Override
	void close();
}
