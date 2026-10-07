package dev.shadowvisuals.modules.player;

import java.util.concurrent.ThreadLocalRandom;

import net.minecraft.client.Minecraft;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;

import dev.shadowvisuals.event.events.AttackEntityEvent;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;

/** Plays a short local sound when you hit an entity. Only you hear it; nothing is sent to the server. */
public final class HitSound extends Module {
	public enum Sound {
		CLICK,
		BELL,
		PLING,
		BASS,
		EXPERIENCE,
		ARROW
	}

	private static final long MIN_INTERVAL_NANOS = 40_000_000L;

	private final ModeSetting<Sound> sound = settings().add(new ModeSetting<>("sound", Sound.CLICK));
	private final NumberSetting volume = settings().add(new NumberSetting("volume", 0.7, 0.05, 1.0, 0.05));
	private final NumberSetting pitch = settings().add(new NumberSetting("pitch", 1.0, 0.5, 2.0, 0.05));
	private final BooleanSetting randomPitch = settings().add(new BooleanSetting("random_pitch", true));
	private final BooleanSetting playersOnly = settings().add(new BooleanSetting("players_only", false));
	private long lastPlayed;

	public HitSound() {
		super("hit_sound", Category.PLAYER);
		on(AttackEntityEvent.class, event -> play(event.target()));
	}

	private void play(Entity target) {
		if (!(target instanceof LivingEntity) || playersOnly.get() && !(target instanceof Player)) {
			return;
		}
		long now = System.nanoTime();
		if (now - lastPlayed < MIN_INTERVAL_NANOS) {
			return;
		}
		lastPlayed = now;
		float finalPitch = pitch.getFloat();
		if (randomPitch.get()) {
			finalPitch *= 0.92f + ThreadLocalRandom.current().nextFloat() * 0.16f;
		}
		Minecraft.getInstance().getSoundManager().play(SimpleSoundInstance.forUI(event(sound.get()), finalPitch, volume.getFloat()));
	}

	private static SoundEvent event(Sound sound) {
		return switch (sound) {
			case CLICK -> SoundEvents.NOTE_BLOCK_HAT.value();
			case BELL -> SoundEvents.NOTE_BLOCK_BELL.value();
			case PLING -> SoundEvents.NOTE_BLOCK_PLING.value();
			case BASS -> SoundEvents.NOTE_BLOCK_BASS.value();
			case EXPERIENCE -> SoundEvents.EXPERIENCE_ORB_PICKUP;
			case ARROW -> SoundEvents.ARROW_HIT_PLAYER;
		};
	}
}
