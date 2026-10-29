package dev.nyxveravisuals.event.events;

/** The client left the world; every world-bound cache must be cleared. */
public final class WorldLeaveEvent {
	public static final WorldLeaveEvent INSTANCE = new WorldLeaveEvent();

	private WorldLeaveEvent() {
	}
}
