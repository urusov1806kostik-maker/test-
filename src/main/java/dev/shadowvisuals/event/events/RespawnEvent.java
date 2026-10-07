package dev.shadowvisuals.event.events;

/** The local player entity was replaced (respawn or dimension travel). */
public final class RespawnEvent {
	public static final RespawnEvent INSTANCE = new RespawnEvent();

	private RespawnEvent() {
	}
}
