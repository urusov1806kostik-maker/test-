package dev.shadowvisuals.modules.world;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.event.events.DeathEvent;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.notification.NotificationManager;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.setting.IntSetting;

/**
 * Saves a waypoint where you die (per world and dimension, only the newest few are kept) and optionally
 * shows a notification with the coordinates. The points are drawn by the Waypoints module.
 */
public final class DeathPoint extends Module {
	private static final DateTimeFormatter TIME = DateTimeFormatter.ofPattern("HH:mm");

	private final ShadowClient client;
	private final IntSetting keep = settings().add(new IntSetting("keep", 3, 1, 10));
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFFF2555A, false));
	private final BooleanSetting notify = settings().add(new BooleanSetting("notify", true));

	public DeathPoint(ShadowClient client) {
		super("death_point", Category.WORLD, true);
		this.client = client;
		on(DeathEvent.class, this::record);
	}

	private void record(DeathEvent event) {
		if (!client.session().inWorld()) {
			return;
		}
		String name = client.i18n().tr("waypoint.death_name", LocalTime.now().format(TIME));
		client.waypoints().addDeathPoint(name, event.x(), event.y(), event.z(), event.dimension(), client.session().worldKey(),
			color.argb(), keep.get());
		if (notify.get()) {
			client.notifications().push(NotificationManager.Type.INFO, client.i18n().tr("module.death_point.name"),
				client.i18n().tr("waypoint.death_saved", event.x(), event.y(), event.z()));
		}
	}
}
