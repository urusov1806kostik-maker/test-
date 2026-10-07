package dev.shadowvisuals.gametest;

import org.lwjgl.glfw.GLFW;

import java.util.Properties;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.screens.DeathScreen;
import net.minecraft.world.level.Level;

import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestDedicatedServerContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestServerConnection;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestSingleplayerContext;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.modules.funtime.ItemBinds;
import dev.shadowvisuals.setting.Keybind;
import dev.shadowvisuals.ui.screen.ClickGuiScreen;
import dev.shadowvisuals.ui.screen.HudEditorScreen;
import dev.shadowvisuals.waypoint.Waypoint;

/**
 * End-to-end client test: launches the real game, drives the GUI with simulated input and records
 * screenshots of every major screen, plus the lifecycle paths that must not crash (spam-opening the GUI,
 * GUI scale, fullscreen and window changes, death and respawn, dimension changes, resource reload, leaving and
 * rejoining a world, and joining, leaving and rejoining a dedicated server).
 */
public final class ShadowVisualsClientGameTest implements FabricClientGameTest {
	@Override
	public void runTest(ClientGameTestContext context) {
		// The CI machine renders on the CPU; small view distances keep world loading within the test timeout.
		context.runOnClient(client -> {
			client.options.renderDistance().set(4);
			client.options.simulationDistance().set(5);
			client.options.framerateLimit().set(30);
		});
		context.waitTicks(10);
		context.getInput().pressKey(GLFW.GLFW_KEY_RIGHT_SHIFT);
		context.waitForScreen(ClickGuiScreen.class);
		context.waitTicks(8);
		context.takeScreenshot("01_clickgui_title_screen");
		context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
		context.waitTicks(10);

		try (TestSingleplayerContext world = context.worldBuilder().create()) {
			world.getClientWorld().waitForChunksRender();
			context.waitTicks(20);
			context.runOnClient(client -> enableShowcaseModules());
			world.getServer().runCommand("time set noon");
			world.getServer().runCommand("give @a minecraft:diamond_sword[minecraft:enchantments={\"minecraft:sharpness\":1}]");
			world.getServer().runCommand("execute at @a run setblock ~2 ~ ~3 minecraft:chest");
			world.getServer().runCommand("execute at @a run setblock ~-2 ~ ~3 minecraft:barrel");
			world.getServer().runCommand("execute at @a run summon minecraft:item ~ ~1 ~4 {Item:{id:\"minecraft:diamond\",count:3}}");
			context.waitTicks(10);
			context.runOnClient(client -> addShowcaseWaypoint(client));
			context.waitTicks(20);
			context.takeScreenshot("02_hud_in_world");
			context.runOnClient(client -> client.player.setXRot(55f));
			context.waitTicks(2);
			context.getInput().holdKeyFor(GLFW.GLFW_KEY_SPACE, 2);
			context.waitTicks(4);
			context.takeScreenshot("02b_jump_circle");

			// FunTime item binds: one keyboard bind (item outside the hotbar) and one mouse bind (hotbar item).
			world.getServer().runCommand("item replace entity @a inventory.5 with minecraft:snowball[minecraft:custom_name=\"Трапка\"] 4");
			world.getServer().runCommand("item replace entity @a hotbar.4 with minecraft:snowball[minecraft:custom_name=\"Дезориентация\"] 4");
			context.waitTicks(5);
			context.runOnClient(client -> {
				ItemBinds binds = ShadowClient.get().modules().get(ItemBinds.class);
				check(binds.isEnabled(), "item binds are not enabled by default");
				binds.bind(ItemBinds.Item.TRAP).set(Keybind.key(GLFW.GLFW_KEY_X));
				binds.bind(ItemBinds.Item.DISORIENTATION).set(Keybind.mouse(GLFW.GLFW_MOUSE_BUTTON_5));
			});
			context.getInput().pressKey(GLFW.GLFW_KEY_X);
			context.waitTicks(10);
			context.runOnClient(client -> check(countNamed(client, "Трапка") == 3, "keyboard item bind did not use the item"));
			context.getInput().pressMouse(GLFW.GLFW_MOUSE_BUTTON_5);
			context.waitTicks(10);
			context.runOnClient(client -> {
				check(countNamed(client, "Дезориентация") == 3, "mouse item bind did not use the item");
				check(client.player.getInventory().getSelectedSlot() == 0, "selected hotbar slot was not restored");
			});
			context.runOnClient(client -> {
				ShadowClient.get().screens().openClickGui();
				if (client.screen instanceof ClickGuiScreen screen) {
					screen.openModuleSettings(ShadowClient.get().modules().get(ItemBinds.class));
				}
			});
			context.waitForScreen(ClickGuiScreen.class);
			context.waitTicks(10);
			context.takeScreenshot("02e_item_binds");
			context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
			context.waitTicks(10);

			// Death records a death point; respawning must keep every module working.
			world.getServer().runCommand("kill @a");
			context.waitForScreen(DeathScreen.class);
			context.waitTicks(30);
			context.takeScreenshot("02c_death_screen");
			context.clickScreenButton("deathScreen.respawn");
			context.waitForScreen(null);
			context.waitTicks(10);
			context.runOnClient(client -> check(client.player != null && client.player.isAlive(), "player did not respawn"));
			context.runOnClient(client -> check(hasDeathPoint(), "no death point was recorded"));

			// Dimension change and back (creative, so the arrival spot cannot hurt the player).
			world.getServer().runCommand("gamemode creative @a");
			world.getServer().runCommand("execute in minecraft:the_nether run tp @a 0 70 0");
			context.waitFor(client -> client.level != null && client.level.dimension() == Level.NETHER);
			world.getClientWorld().waitForChunksRender();
			context.waitTicks(10);
			context.runOnClient(client -> check("minecraft:the_nether".equals(ShadowClient.get().session().dimension()), "dimension change not tracked"));
			context.takeScreenshot("02d_nether");
			world.getServer().runCommand("execute in minecraft:overworld run tp @a 0 -60 0");
			context.waitFor(client -> client.level != null && client.level.dimension() == Level.OVERWORLD);
			world.getClientWorld().waitForChunksRender();
			world.getServer().runCommand("gamemode survival @a");
			world.getServer().runCommand("effect give @a minecraft:instant_health 1 5");
			context.waitTicks(10);

			for (int i = 0; i < 6; i++) {
				context.getInput().pressKey(GLFW.GLFW_KEY_RIGHT_SHIFT);
				context.waitTick();
			}
			context.waitTicks(10);
			context.getInput().pressKey(GLFW.GLFW_KEY_RIGHT_SHIFT);
			context.waitTicks(4);
			openClickGui(context);
			context.takeScreenshot("03_clickgui_visual");

			for (String page : new String[] {"HUD", "PLAYER", "WORLD", "FUNTIME", "CONFIG", "SETTINGS", "FAVORITES"}) {
				context.runOnClient(client -> selectPage(client, page));
				context.waitTicks(6);
				context.takeScreenshot("04_page_" + page.toLowerCase(java.util.Locale.ROOT));
			}
			context.runOnClient(client -> {
				ShadowClient.get().settings().language.set(dev.shadowvisuals.i18n.Localization.Language.UKRAINIAN);
				selectPage(client, "PLAYER");
			});
			context.waitTicks(6);
			context.takeScreenshot("04_page_player_ukrainian");
			context.runOnClient(client -> ShadowClient.get().settings().language.set(dev.shadowvisuals.i18n.Localization.Language.AUTO));
			context.runOnClient(client -> selectPage(client, "VISUAL"));
			context.waitTicks(4);
			context.getInput().typeChars("hud");
			context.waitTicks(6);
			context.takeScreenshot("05_search");
			context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
			context.waitTicks(4);

			context.runOnClient(client -> ShadowClient.get().screens().openHudEditor());
			context.waitForScreen(HudEditorScreen.class);
			context.waitTicks(10);
			context.takeScreenshot("06_hud_editor");
			context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
			context.waitTicks(10);
			context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
			context.waitTicks(10);

			for (int scale : new int[] {1, 2, 4, 0}) {
				context.runOnClient(client -> {
					client.options.guiScale().set(scale);
					client.resizeDisplay();
				});
				openClickGui(context);
				context.takeScreenshot("07_gui_scale_" + scale);
				context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
				context.waitTicks(10);
			}
			context.runOnClient(client -> client.getWindow().toggleFullScreen());
			context.waitTicks(10);
			openClickGui(context);
			context.takeScreenshot("07_fullscreen");
			context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
			context.waitTicks(10);
			context.runOnClient(client -> client.getWindow().toggleFullScreen());
			context.waitTicks(10);
			context.getInput().resizeWindow(1280, 720);
			context.waitTicks(4);
			openClickGui(context);
			context.takeScreenshot("08_window_720p");
			context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
			context.waitTicks(10);

			context.runOnClient(Minecraft::reloadResourcePacks);
			context.waitTicks(60);
			context.takeScreenshot("09_after_reload");
		}
		context.getInput().resizeWindow(854, 480);
		context.waitTicks(20);
		try (TestSingleplayerContext world = context.worldBuilder().create()) {
			world.getClientWorld().waitForChunksRender();
			context.waitTicks(10);
			context.takeScreenshot("10_rejoined_world");
		}

		Properties properties = new Properties();
		properties.setProperty("view-distance", "4");
		properties.setProperty("simulation-distance", "4");
		try (TestDedicatedServerContext server = context.worldBuilder().createServer(properties)) {
			try (TestServerConnection connection = server.connect()) {
				connection.getClientWorld().waitForChunksRender();
				context.waitTicks(20);
				context.runOnClient(client -> check(ShadowClient.get().session().worldKey().startsWith("mp:"), "multiplayer session not detected"));
				// Let the join toasts slide away so they do not cover the player list.
				context.waitTicks(140);
				context.getInput().holdKey(options -> options.keyPlayerList);
				context.waitTicks(6);
				context.takeScreenshot("11_multiplayer_tab");
				context.getInput().releaseKey(options -> options.keyPlayerList);
				context.runOnClient(client -> ShadowClient.get().modules().byId("custom_tab").setEnabled(true));
				context.getInput().holdKey(options -> options.keyPlayerList);
				context.waitTicks(10);
				context.takeScreenshot("11b_multiplayer_custom_tab");
				context.getInput().releaseKey(options -> options.keyPlayerList);
			}
			context.waitTicks(20);
			try (TestServerConnection connection = server.connect()) {
				connection.getClientWorld().waitForChunksRender();
				context.waitTicks(10);
				openClickGui(context);
				context.takeScreenshot("12_reconnected_clickgui");
				context.getInput().pressKey(GLFW.GLFW_KEY_ESCAPE);
				context.waitTicks(10);
			}
		}
		context.waitTicks(10);
		context.runOnClient(client -> check(!ShadowClient.get().session().inWorld(), "session still active after disconnect"));
	}

	private static void check(boolean condition, String message) {
		if (!condition) {
			throw new AssertionError(message);
		}
	}

	private static int countNamed(Minecraft client, String name) {
		int total = 0;
		var inventory = client.player.getInventory();
		for (int slot = 0; slot < inventory.getContainerSize(); slot++) {
			var stack = inventory.getItem(slot);
			if (!stack.isEmpty() && stack.getHoverName().getString().equals(name)) {
				total += stack.getCount();
			}
		}
		return total;
	}

	private static boolean hasDeathPoint() {
		var shadow = ShadowClient.get();
		for (Waypoint waypoint : shadow.waypoints().inWorld(shadow.session().worldKey())) {
			if (waypoint.kind() == Waypoint.Kind.DEATH) {
				return true;
			}
		}
		return false;
	}

	/** Turns on a representative set of modules so screenshots show real HUD and visuals. */
	private static void enableShowcaseModules() {
		var modules = ShadowClient.get().modules();
		for (String id : new String[] {"watermark", "active_modules", "keybinds", "fps", "ping", "coordinates", "bps", "compass",
			"armor", "inventory", "session_info", "server_info", "totem_counter", "warnings", "fullbright", "time_changer",
			"jump_circle", "trails", "glint_color", "container_visuals", "item_esp", "block_outline", "waypoints"}) {
			var module = modules.byId(id);
			if (module != null) {
				module.setEnabled(true);
			}
		}
	}

	private static void addShowcaseWaypoint(Minecraft client) {
		var shadow = ShadowClient.get();
		if (client.player != null && shadow.session().inWorld()) {
			shadow.waypoints().create("Base", client.player.getBlockX() + 30, client.player.getBlockY(), client.player.getBlockZ() + 40,
				shadow.session().dimension(), shadow.session().worldKey(), 0xFF5BD8F2);
		}
	}

	private static void openClickGui(ClientGameTestContext context) {
		context.runOnClient(client -> ShadowClient.get().screens().openClickGui());
		context.waitForScreen(ClickGuiScreen.class);
		context.waitTicks(10);
	}

	private static void selectPage(Minecraft client, String page) {
		if (client.screen instanceof ClickGuiScreen screen) {
			screen.selectPage(dev.shadowvisuals.ui.clickgui.Page.valueOf(page));
		}
	}
}
