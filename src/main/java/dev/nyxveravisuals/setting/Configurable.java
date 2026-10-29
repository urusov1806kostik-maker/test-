package dev.nyxveravisuals.setting;

/** Anything that exposes a setting tree to the GUI and to persistence. */
public interface Configurable {
	SettingRegistry settings();
}
