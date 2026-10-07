package dev.shadowvisuals.hud;

import java.util.function.BooleanSupplier;

import net.minecraft.resources.Identifier;

import net.fabricmc.fabric.api.client.rendering.v1.hud.HudElement;
import net.fabricmc.fabric.api.client.rendering.v1.hud.HudElementRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.hud.VanillaHudElements;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.modules.Hooks;
import dev.shadowvisuals.modules.hud.PotionEffectsHud;
import dev.shadowvisuals.modules.iface.CustomBossBar;
import dev.shadowvisuals.modules.iface.CustomCrosshair;
import dev.shadowvisuals.modules.iface.CustomHotbar;
import dev.shadowvisuals.modules.iface.CustomScoreboard;
import dev.shadowvisuals.modules.iface.CustomTab;

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
		hideWhen(VanillaHudElements.SCOREBOARD, () -> Hooks.enabled(CustomScoreboard.class) != null);
		hideWhen(VanillaHudElements.BOSS_BAR, () -> Hooks.enabled(CustomBossBar.class) != null);
		replaceWhen(VanillaHudElements.CROSSHAIR, () -> Hooks.enabled(CustomCrosshair.class) != null,
			(graphics, delta) -> client.modules().get(CustomCrosshair.class).render(graphics, delta));
		replaceWhen(VanillaHudElements.HOTBAR, () -> Hooks.enabled(CustomHotbar.class) != null,
			(graphics, delta) -> client.modules().get(CustomHotbar.class).render(graphics, delta));
		replaceWhen(VanillaHudElements.PLAYER_LIST, () -> Hooks.enabled(CustomTab.class) != null,
			(graphics, delta) -> client.modules().get(CustomTab.class).render(graphics, delta));
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
