package dev.nyxveravisuals.ui;

import com.mojang.blaze3d.platform.InputConstants;

import dev.nyxveravisuals.i18n.Localization;
import dev.nyxveravisuals.setting.Keybind;

/** Human-readable names for binds, using the game's localized key names. */
public final class KeyNames {
	private KeyNames() {
	}

	public static String name(Keybind bind, Localization i18n) {
		if (!bind.isBound()) {
			return i18n.tr("ui.bind.none");
		}
		InputConstants.Key key = bind.device() == Keybind.Device.MOUSE
			? InputConstants.Type.MOUSE.getOrCreate(bind.code())
			: InputConstants.Type.KEYSYM.getOrCreate(bind.code());
		String name = key.getDisplayName().getString();
		return name.isBlank() ? "#" + bind.code() : name;
	}
}
