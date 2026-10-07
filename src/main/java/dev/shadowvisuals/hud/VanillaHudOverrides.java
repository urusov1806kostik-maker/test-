package dev.shadowvisuals.hud;

import java.util.function.BooleanSupplier;

import net.minecraft.resources.Identifier;

import net.fabricmc.fabric.api.client.rendering.v1.hud.HudElement;
import net.fabricmc.fabric.api.client.rendering.v1.hud.HudElementRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.hud.VanillaHudElements;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.modules.hud.PotionEffectsHud;

/**
 * Wraps vanilla HUD layers through Fabric's HUD registry instead of mixins: a layer is skipped (or drawn by
 * a client replacement) only while the corresponding module asks for it, otherwise vanilla renders as usual.
 */
public final class VanillaHudOverrides {
	private VanillaHudOverrides() {
	}

	public static void register(ShadowClient client) {
		hideWhen(VanillaHudElements.STATUS_EFFECTS, () -> {
			PotionEffectsHud effects = client.modules().get(PotionEffectsHud.class);
			return effects != null && effects.hidesVanilla();
		});
	}

	/** Skips the vanilla layer while {@code condition} holds. */
	public static void hideWhen(Identifier layer, BooleanSupplier condition) {
		HudElementRegistry.replaceElement(layer, original -> (graphics, deltaTracker) -> {
			if (!condition.getAsBoolean()) {
				original.render(graphics, deltaTracker);
			}
		});
	}

	/** Draws {@code replacement} instead of the vanilla layer while {@code condition} holds. */
	public static void replaceWhen(Identifier layer, BooleanSupplier condition, HudElement replacement) {
		HudElementRegistry.replaceElement(layer, original -> (graphics, deltaTracker) -> {
			if (condition.getAsBoolean()) {
				replacement.render(graphics, deltaTracker);
			} else {
				original.render(graphics, deltaTracker);
			}
		});
	}
}
