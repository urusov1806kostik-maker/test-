package dev.nyxveravisuals.core;

import org.lwjgl.glfw.GLFW;

import dev.nyxveravisuals.animation.AnimationClock;
import dev.nyxveravisuals.i18n.Localization;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.Configurable;
import dev.nyxveravisuals.setting.Keybind;
import dev.nyxveravisuals.setting.KeybindSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.setting.SettingGroup;
import dev.nyxveravisuals.setting.SettingRegistry;

/** Global (not per-profile) client preferences: language, accessibility, interface and debug options. */
public final class ClientSettings implements Configurable {
	public enum NotificationCorner {
		TOP_RIGHT,
		BOTTOM_RIGHT,
		BOTTOM_LEFT,
		TOP_LEFT
	}

	private final SettingRegistry settings = new SettingRegistry("client");

	private final SettingGroup interfaceGroup = settings.add(new SettingGroup("interface"));
	public final ModeSetting<Localization.Language> language = settings.add(interfaceGroup, new ModeSetting<>("language", Localization.Language.AUTO));
	public final KeybindSetting guiKey = settings.add(interfaceGroup, new KeybindSetting("gui_key", Keybind.key(GLFW.GLFW_KEY_RIGHT_SHIFT)));
	public final NumberSetting uiScale = settings.add(interfaceGroup, new NumberSetting("ui_scale", 1.0, 0.7, 1.5, 0.05).suffix("x"));
	public final BooleanSetting customFont = settings.add(interfaceGroup, new BooleanSetting("custom_font", true));
	public final BooleanSetting backgroundBlur = settings.add(interfaceGroup, new BooleanSetting("background_blur", true));
	public final BooleanSetting uiSounds = settings.add(interfaceGroup, new BooleanSetting("ui_sounds", true));
	public final NumberSetting uiVolume = settings.add(interfaceGroup, new NumberSetting("ui_volume", 0.5, 0.0, 1.0, 0.05))
		.visibleWhen(uiSounds::get);

	private final SettingGroup notificationGroup = settings.add(new SettingGroup("notifications"));
	public final BooleanSetting notifications = settings.add(notificationGroup, new BooleanSetting("notifications_enabled", true));
	public final BooleanSetting toggleNotifications = settings.add(notificationGroup, new BooleanSetting("toggle_notifications", true))
		.visibleWhen(notifications::get);
	public final ModeSetting<NotificationCorner> notificationCorner = settings.add(notificationGroup,
		new ModeSetting<>("notification_corner", NotificationCorner.BOTTOM_RIGHT)).visibleWhen(notifications::get);

	private final SettingGroup accessibility = settings.add(new SettingGroup("accessibility"));
	public final ModeSetting<AnimationClock.Mode> animations = settings.add(accessibility, new ModeSetting<>("animations", AnimationClock.Mode.FULL));
	public final BooleanSetting highContrast = settings.add(accessibility, new BooleanSetting("high_contrast", false));
	public final NumberSetting textScale = settings.add(accessibility, new NumberSetting("text_scale", 1.0, 0.85, 1.3, 0.05).suffix("x"));

	private final SettingGroup advanced = settings.add(new SettingGroup("advanced", false));
	public final BooleanSetting debugMode = settings.add(advanced, new BooleanSetting("debug_mode", false));

	@Override
	public SettingRegistry settings() {
		return settings;
	}
}
