package dev.shadowvisuals.event.events;

/** Client resources finished reloading (resource packs, language, F3+T). */
public final class ResourceReloadEvent {
	public static final ResourceReloadEvent INSTANCE = new ResourceReloadEvent();

	private ResourceReloadEvent() {
	}
}
