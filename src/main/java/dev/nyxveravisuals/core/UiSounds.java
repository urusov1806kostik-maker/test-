package dev.nyxveravisuals.core;

import net.minecraft.client.Minecraft;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.sounds.SoundEvents;

/** Subtle interface sounds; respect the user's toggle/volume and never play more than one per 50 ms. */
public final class UiSounds {
	public enum Kind {
		CLICK(1.35f),
		TOGGLE_ON(1.55f),
		TOGGLE_OFF(1.15f),
		OPEN(1.25f);

		private final float pitch;

		Kind(float pitch) {
			this.pitch = pitch;
		}
	}

	private static final long MIN_INTERVAL_NANOS = 50_000_000L;

	private final ClientSettings settings;
	private long lastPlayed;

	public UiSounds(ClientSettings settings) {
		this.settings = settings;
	}

	public void play(Kind kind) {
		if (!settings.uiSounds.get()) {
			return;
		}
		long now = System.nanoTime();
		if (now - lastPlayed < MIN_INTERVAL_NANOS) {
			return;
		}
		lastPlayed = now;
		float volume = settings.uiVolume.getFloat() * 0.45f;
		if (volume <= 0.001f) {
			return;
		}
		Minecraft.getInstance().getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.UI_BUTTON_CLICK.value(), kind.pitch, volume));
	}
}
