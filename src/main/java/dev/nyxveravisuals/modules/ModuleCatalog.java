package dev.nyxveravisuals.modules;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.hud.HudAnchor;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.ModuleManager;
import dev.nyxveravisuals.modules.funtime.CooldownHud;
import dev.nyxveravisuals.modules.funtime.WarningsHud;
import dev.nyxveravisuals.modules.hud.ActiveModulesHud;
import dev.nyxveravisuals.modules.hud.ArmorHud;
import dev.nyxveravisuals.modules.hud.CompassHud;
import dev.nyxveravisuals.modules.hud.CoordinatesHud;
import dev.nyxveravisuals.modules.hud.FpsHud;
import dev.nyxveravisuals.modules.hud.InventoryHud;
import dev.nyxveravisuals.modules.hud.ItemCounterHud;
import dev.nyxveravisuals.modules.hud.KeybindsHud;
import dev.nyxveravisuals.modules.hud.PingHud;
import dev.nyxveravisuals.modules.hud.PotionEffectsHud;
import dev.nyxveravisuals.modules.hud.ServerInfoHud;
import dev.nyxveravisuals.modules.hud.SessionInfoHud;
import dev.nyxveravisuals.modules.hud.SpeedHud;
import dev.nyxveravisuals.modules.hud.TargetHud;
import dev.nyxveravisuals.modules.hud.WatermarkHud;
import dev.nyxveravisuals.modules.utility.RecordingMode;

/** The single place where every built-in module is registered, in display order. */
public final class ModuleCatalog {
	private ModuleCatalog() {
	}

	public static void registerAll(NyxveraClient client) {
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
		modules.register(new dev.nyxveravisuals.modules.visual.NameTags(client));
		modules.register(new dev.nyxveravisuals.modules.visual.BlockOutline());
		modules.register(new dev.nyxveravisuals.modules.visual.GlintColor());
		modules.register(new dev.nyxveravisuals.modules.visual.MusicLyrics(client));
		modules.register(new dev.nyxveravisuals.modules.visual.FullBright());
		modules.register(new dev.nyxveravisuals.modules.visual.FireOverlay());
		modules.register(new dev.nyxveravisuals.modules.visual.OverlayControl());
		modules.register(new dev.nyxveravisuals.modules.visual.ParticleModifier());

		// Player
		modules.register(new dev.nyxveravisuals.modules.player.JumpCircle());
		modules.register(new dev.nyxveravisuals.modules.player.Trails());
		modules.register(new dev.nyxveravisuals.modules.player.HitParticles());
		modules.register(new dev.nyxveravisuals.modules.player.HitSound());
		modules.register(new dev.nyxveravisuals.modules.player.HitColor());
		modules.register(new dev.nyxveravisuals.modules.player.ViewModel());
		modules.register(new dev.nyxveravisuals.modules.player.SwingAnimation());

		// World
		modules.register(new dev.nyxveravisuals.modules.world.TimeChanger());
		modules.register(new dev.nyxveravisuals.modules.world.WeatherControl());
		modules.register(new dev.nyxveravisuals.modules.world.FogControl());
		modules.register(new dev.nyxveravisuals.modules.world.WorldColor());
		modules.register(new dev.nyxveravisuals.modules.world.SkyColor());
		modules.register(new dev.nyxveravisuals.modules.world.AmbientColor());
		modules.register(new dev.nyxveravisuals.modules.world.Waypoints(client));
		modules.register(new dev.nyxveravisuals.modules.world.DeathPoint(client));

		// Camera
		modules.register(new dev.nyxveravisuals.modules.camera.Zoom());
		modules.register(new dev.nyxveravisuals.modules.camera.FreeLook());
		modules.register(new dev.nyxveravisuals.modules.camera.CameraSettings());
		modules.register(new dev.nyxveravisuals.modules.camera.HurtCamera());
		modules.register(new dev.nyxveravisuals.modules.camera.ViewBobbing());
		modules.register(new dev.nyxveravisuals.modules.camera.FovControl());

		// Interface
		modules.register(new dev.nyxveravisuals.modules.iface.CustomCrosshair(client));
		modules.register(new dev.nyxveravisuals.modules.iface.CustomHotbar(client));
		modules.register(new dev.nyxveravisuals.modules.iface.CustomScoreboard());
		modules.register(new dev.nyxveravisuals.modules.iface.CustomTab(client));
		modules.register(new dev.nyxveravisuals.modules.iface.CustomBossBar());
		modules.register(new dev.nyxveravisuals.modules.iface.ChatVisuals(client));
		modules.register(new dev.nyxveravisuals.modules.iface.CustomTooltips(client));

		// FunTime Helper
		modules.register(new ItemCounterHud("totem_counter", Category.FUNTIME, "minecraft:totem_of_undying", HudAnchor.BOTTOM_CENTER, 112, -4));
		modules.register(new ItemCounterHud("pearl_counter", Category.FUNTIME, "minecraft:ender_pearl", HudAnchor.BOTTOM_CENTER, 146, -4));
		modules.register(new ItemCounterHud("crystal_counter", Category.FUNTIME, "minecraft:end_crystal", HudAnchor.BOTTOM_CENTER, 180, -4));
		modules.register(new ItemCounterHud("item_counters", Category.FUNTIME,
			"minecraft:golden_apple, minecraft:enchanted_golden_apple, minecraft:experience_bottle", HudAnchor.MIDDLE_RIGHT, -4, 0));
		modules.register(new CooldownHud());
		modules.register(new WarningsHud());
		modules.register(new dev.nyxveravisuals.modules.funtime.ItemBinds(client));

		// Utility
		modules.register(new RecordingMode());
		modules.register(new dev.nyxveravisuals.modules.utility.AltManager(client));
	}
}
