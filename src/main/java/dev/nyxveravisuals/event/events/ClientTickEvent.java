package dev.nyxveravisuals.event.events;

/** Fired at the start and end of every client tick (20 per second), also in menus. */
public final class ClientTickEvent {
	public static final ClientTickEvent PRE = new ClientTickEvent(true);
	public static final ClientTickEvent POST = new ClientTickEvent(false);

	private final boolean pre;

	private ClientTickEvent(boolean pre) {
		this.pre = pre;
	}

	public boolean isPre() {
		return pre;
	}
}
