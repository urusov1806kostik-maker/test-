package dev.shadowvisuals.gametest;

import org.lwjgl.glfw.GLFW;

import net.minecraft.client.Minecraft;

import net.fabricmc.fabric.api.client.gametest.v1.FabricClientGameTest;
import net.fabricmc.fabric.api.client.gametest.v1.context.ClientGameTestContext;
import net.fabricmc.fabric.api.client.gametest.v1.context.TestSingleplayerContext;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.ui.screen.ClickGuiScreen;
import dev.shadowvisuals.ui.screen.HudEditorScreen;

/**
 * End-to-end client test: launches the real game, drives the GUI with simulated input and records
 * screenshots of every major screen, plus the lifecycle paths that must not crash (spam-opening the GUI,
 * GUI scale and window changes, resource reload, leaving and rejoining a world).
 */
public final class ShadowVisualsClientGameTest implements FabricClientGameTest {
	@Override
	public void runTest(ClientGameTestContext context) {
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
			context.getInput().holdKeyFor(GLFW.GLFW_KEY_SPACE, 2);
			context.waitTicks(3);
			context.takeScreenshot("02b_jump_circle");

			for (int i = 0; i < 6; i++) {
				context.getInput().pressKey(GLFW.GLFW_KEY_RIGHT_SHIFT);
				context.waitTick();
			}
			context.waitTicks(10);
			context.getInput().pressKey(GLFW.GLFW_KEY_RIGHT_SHIFT);
			context.waitTicks(4);
			openClickGui(context);
			context.takeScreenshot("03_clickgui_visual");

			for (String page : new String[] {"HUD", "FUNTIME", "CONFIG", "SETTINGS", "FAVORITES"}) {
				context.runOnClient(client -> selectPage(client, page));
				context.waitTicks(6);
				context.takeScreenshot("04_page_" + page.toLowerCase(java.util.Locale.ROOT));
			}
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
		context.waitTicks(100);
		try (TestSingleplayerContext world = context.worldBuilder().create()) {
			world.getClientWorld().waitForChunksRender();
			context.waitTicks(10);
			context.takeScreenshot("10_rejoined_world");
		}
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
