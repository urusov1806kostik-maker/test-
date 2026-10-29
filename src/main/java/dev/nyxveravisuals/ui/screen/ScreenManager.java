package dev.nyxveravisuals.ui.screen;

import net.minecraft.client.Minecraft;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.core.UiSounds;

/** Opens client screens safely (never stacks duplicates, reverses a closing ClickGUI instead). */
public final class ScreenManager {
	private final NyxveraClient client;

	public ScreenManager(NyxveraClient client) {
		this.client = client;
	}

	public void openClickGui() {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.screen instanceof ClickGuiScreen existing) {
			existing.reopen();
			return;
		}
		if (minecraft.screen != null && !(minecraft.screen instanceof net.minecraft.client.gui.screens.TitleScreen)) {
			return;
		}
		client.modules().releaseHeldBinds();
		client.sounds().play(UiSounds.Kind.OPEN);
		ClickGuiScreen screen = new ClickGuiScreen(client);
		screen.setParent(minecraft.screen);
		minecraft.setScreen(screen);
	}

	public void openHudEditor() {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.screen instanceof HudEditorScreen) {
			return;
		}
		client.modules().releaseHeldBinds();
		HudEditorScreen screen = new HudEditorScreen(client);
		if (minecraft.screen instanceof ClickGuiScreen clickGui) {
			screen.setParent(clickGui);
		}
		minecraft.setScreen(screen);
	}
}
