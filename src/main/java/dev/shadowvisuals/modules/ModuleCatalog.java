package dev.shadowvisuals.modules;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.ModuleManager;
import dev.shadowvisuals.modules.funtime.CooldownHud;
import dev.shadowvisuals.modules.funtime.WarningsHud;
import dev.shadowvisuals.modules.hud.ActiveModulesHud;
import dev.shadowvisuals.modules.hud.ArmorHud;
import dev.shadowvisuals.modules.hud.CompassHud;
import dev.shadowvisuals.modules.hud.CoordinatesHud;
import dev.shadowvisuals.modules.hud.FpsHud;
import dev.shadowvisuals.modules.hud.InventoryHud;
import dev.shadowvisuals.modules.hud.ItemCounterHud;
import dev.shadowvisuals.modules.hud.KeybindsHud;
import dev.shadowvisuals.modules.hud.PingHud;
import dev.shadowvisuals.modules.hud.PotionEffectsHud;
import dev.shadowvisuals.modules.hud.ServerInfoHud;
import dev.shadowvisuals.modules.hud.SessionInfoHud;
import dev.shadowvisuals.modules.hud.SpeedHud;
import dev.shadowvisuals.modules.hud.TargetHud;
import dev.shadowvisuals.modules.hud.WatermarkHud;
import dev.shadowvisuals.modules.utility.RecordingMode;

/** The single place where every built-in module is registered, in display order. */
public final class ModuleCatalog {
	private ModuleCatalog() {
	}

	public static void registerAll(ShadowClient client) {
		ModuleManager modules = client.modules();

		// HUD
		modules.register(new WatermarkHud(client));
		modules.register(new ActiveModulesHud(client));
		modules.register(new KeybindsHud(client));
		modules.register(new FpsHud());
		modules.register(new PingHud());
		modules.register(new CoordinatesHud());
		modules.register(new SpeedHud());
		modules.register(new CompassHud());
		modules.register(new PotionEffectsHud());
		modules.register(new ArmorHud());
		modules.register(new InventoryHud());
		modules.register(new TargetHud(client));
		modules.register(new SessionInfoHud(client));
		modules.register(new ServerInfoHud(client));

		// Visual
		modules.register(new dev.shadowvisuals.modules.visual.PlayerEsp(client));
		modules.register(new dev.shadowvisuals.modules.visual.NameTags(client));
		modules.register(new dev.shadowvisuals.modules.visual.ItemEsp(client));
		modules.register(new dev.shadowvisuals.modules.visual.ContainerVisuals());
		modules.register(new dev.shadowvisuals.modules.visual.BlockOutline());
		modules.register(new dev.shadowvisuals.modules.visual.JumpCircle());
		modules.register(new dev.shadowvisuals.modules.visual.Trails());
		modules.register(new dev.shadowvisuals.modules.visual.HitParticles());
		modules.register(new dev.shadowvisuals.modules.visual.HitSound());
		modules.register(new dev.shadowvisuals.modules.visual.GlintColor());
		modules.register(new dev.shadowvisuals.modules.visual.FullBright());
		modules.register(new dev.shadowvisuals.modules.visual.HitColor());
		modules.register(new dev.shadowvisuals.modules.visual.ViewModel());
		modules.register(new dev.shadowvisuals.modules.visual.SwingAnimation());
		modules.register(new dev.shadowvisuals.modules.visual.FireOverlay());
		modules.register(new dev.shadowvisuals.modules.visual.OverlayControl());
		modules.register(new dev.shadowvisuals.modules.visual.ParticleModifier());

		// World
		modules.register(new dev.shadowvisuals.modules.world.TimeChanger());
		modules.register(new dev.shadowvisuals.modules.world.WeatherControl());
		modules.register(new dev.shadowvisuals.modules.world.FogControl());
		modules.register(new dev.shadowvisuals.modules.world.WorldColor());
		modules.register(new dev.shadowvisuals.modules.world.SkyColor());
		modules.register(new dev.shadowvisuals.modules.world.AmbientColor());
		modules.register(new dev.shadowvisuals.modules.world.Waypoints(client));
		modules.register(new dev.shadowvisuals.modules.world.DeathPoint(client));

		// Camera
		modules.register(new dev.shadowvisuals.modules.camera.Zoom());
		modules.register(new dev.shadowvisuals.modules.camera.FreeLook());
		modules.register(new dev.shadowvisuals.modules.camera.CameraSettings());
		modules.register(new dev.shadowvisuals.modules.camera.HurtCamera());
		modules.register(new dev.shadowvisuals.modules.camera.ViewBobbing());
		modules.register(new dev.shadowvisuals.modules.camera.FovControl());

		// Interface
		modules.register(new dev.shadowvisuals.modules.iface.CustomCrosshair(client));
		modules.register(new dev.shadowvisuals.modules.iface.CustomHotbar(client));
		modules.register(new dev.shadowvisuals.modules.iface.CustomScoreboard());
		modules.register(new dev.shadowvisuals.modules.iface.CustomTab(client));
		modules.register(new dev.shadowvisuals.modules.iface.CustomBossBar());
		modules.register(new dev.shadowvisuals.modules.iface.ChatVisuals(client));
		modules.register(new dev.shadowvisuals.modules.iface.CustomTooltips(client));

		// FunTime Helper
		modules.register(new ItemCounterHud("totem_counter", Category.FUNTIME, "minecraft:totem_of_undying", HudAnchor.BOTTOM_CENTER, -140, -48));
		modules.register(new ItemCounterHud("pearl_counter", Category.FUNTIME, "minecraft:ender_pearl", HudAnchor.BOTTOM_CENTER, -140, -70));
		modules.register(new ItemCounterHud("crystal_counter", Category.FUNTIME, "minecraft:end_crystal", HudAnchor.BOTTOM_CENTER, -140, -92));
		modules.register(new ItemCounterHud("item_counters", Category.FUNTIME,
			"minecraft:golden_apple, minecraft:enchanted_golden_apple, minecraft:experience_bottle", HudAnchor.MIDDLE_RIGHT, -4, 0));
		modules.register(new CooldownHud());
		modules.register(new WarningsHud());

		// Utility
		modules.register(new RecordingMode());
	}
}
