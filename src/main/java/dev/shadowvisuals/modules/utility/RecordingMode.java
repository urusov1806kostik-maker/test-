package dev.shadowvisuals.modules.utility;

import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.BooleanSetting;

/**
 * Hides potentially private information for videos and streams: player name, coordinates, server address
 * and HUD elements marked as private. Every HUD element and panel reads {@link #privacy()}.
 */
public final class RecordingMode extends Module {
	private final BooleanSetting hideName = settings().add(new BooleanSetting("hide_name", true));
	private final BooleanSetting hideCoordinates = settings().add(new BooleanSetting("hide_coordinates", true));
	private final BooleanSetting hideServer = settings().add(new BooleanSetting("hide_server", true));
	private final BooleanSetting hidePrivateHud = settings().add(new BooleanSetting("hide_private_hud", false));

	public RecordingMode() {
		super("recording_mode", Category.UTILITY);
	}

	public HudContext.Privacy privacy() {
		return new HudContext.Privacy(hideName.get(), hideCoordinates.get(), hideServer.get(), hidePrivateHud.get());
	}
}
