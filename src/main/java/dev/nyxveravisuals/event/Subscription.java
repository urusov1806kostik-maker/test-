package dev.nyxveravisuals.event;

/** Handle returned by {@link EventBus#subscribe}; unsubscribing is idempotent. */
public final class Subscription {
	private final EventBus bus;
	private final Class<?> type;
	private final EventBus.Listener listener;

	Subscription(EventBus bus, Class<?> type, EventBus.Listener listener) {
		this.bus = bus;
		this.type = type;
		this.listener = listener;
	}

	public boolean isActive() {
		return listener.active;
	}

	public void unsubscribe() {
		if (listener.active) {
			listener.active = false;
			bus.unsubscribe(type, listener);
		}
	}
}
