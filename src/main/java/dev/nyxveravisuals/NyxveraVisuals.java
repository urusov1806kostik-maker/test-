package dev.nyxveravisuals;

import com.mojang.blaze3d.vertex.PoseStack;

import net.minecraft.client.Minecraft;
import net.minecraft.resources.Identifier;
import net.minecraft.server.packs.PackType;
import net.minecraft.server.packs.resources.ResourceManagerReloadListener;
import net.minecraft.world.InteractionResult;

import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientLifecycleEvents;
import net.fabricmc.fabric.api.client.event.lifecycle.v1.ClientTickEvents;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.fabricmc.fabric.api.client.rendering.v1.hud.HudElementRegistry;
import net.fabricmc.fabric.api.client.rendering.v1.hud.VanillaHudElements;
import net.fabricmc.fabric.api.client.rendering.v1.world.WorldRenderEvents;
import net.fabricmc.fabric.api.client.screen.v1.ScreenEvents;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;
import net.fabricmc.fabric.api.resource.v1.ResourceLoader;
import net.fabricmc.loader.api.FabricLoader;

import dev.nyxveravisuals.core.ClientInfo;
import dev.nyxveravisuals.core.Log;
import dev.nyxveravisuals.event.events.AttackEntityEvent;
import dev.nyxveravisuals.event.events.WorldRenderEvent;
import dev.nyxveravisuals.modules.Hooks;
import dev.nyxveravisuals.modules.visual.BlockOutline;
import dev.nyxveravisuals.render.WorldRenderer3D;

/** Fabric entrypoint: creates the client and connects it to Fabric API callbacks. */
public final class NyxveraVisuals implements ClientModInitializer {
	@Override
	public void onInitializeClient() {
		FabricLoader.getInstance().getModContainer(ClientInfo.MOD_ID)
			.ifPresent(container -> ClientInfo.setVersion(container.getMetadata().getVersion().getFriendlyString()));
		java.nio.file.Path configDir = FabricLoader.getInstance().getConfigDir().resolve(ClientInfo.MOD_ID);
		migrateOldConfig(FabricLoader.getInstance().getConfigDir().resolve("shadowvisuals"), configDir);
		NyxveraClient client = new NyxveraClient(configDir);
		NyxveraClient.setInstance(client);
		client.initialize();

		ClientLifecycleEvents.CLIENT_STARTED.register(minecraft -> client.onClientStarted());
		ClientLifecycleEvents.CLIENT_STOPPING.register(minecraft -> client.shutdown());
		ClientTickEvents.START_CLIENT_TICK.register(minecraft -> client.onTick(minecraft, true));
		ClientTickEvents.END_CLIENT_TICK.register(minecraft -> client.onTick(minecraft, false));
		ClientPlayConnectionEvents.JOIN.register((handler, sender, minecraft) -> client.onJoin(minecraft));
		ClientPlayConnectionEvents.DISCONNECT.register((handler, minecraft) -> client.onLeave());

		// Below chat and the player list, so those vanilla overlays stay readable on top of the client HUD.
		HudElementRegistry.attachElementBefore(VanillaHudElements.CHAT, id("hud"), client::renderHud);
		dev.nyxveravisuals.hud.VanillaHudOverrides.register(client);
		WorldRenderEvents.END_MAIN.register(context -> {
			Minecraft minecraft = Minecraft.getInstance();
			if (minecraft.level == null) {
				return;
			}
			PoseStack poses = context.matrices();
			WorldRenderer3D.Frame frame = new WorldRenderer3D.Frame(poses, context.consumers(),
				context.worldState().cameraRenderState.pos,
				minecraft.getDeltaTracker().getGameTimeDeltaPartialTick(false));
			client.events().post(new WorldRenderEvent(frame));
		});
		WorldRenderEvents.BEFORE_BLOCK_OUTLINE.register((context, outline) -> {
			BlockOutline blockOutline = Hooks.enabled(BlockOutline.class);
			return blockOutline == null || blockOutline.render(context, outline);
		});
		ScreenEvents.AFTER_INIT.register((minecraft, screen, width, height) ->
			ScreenEvents.afterRender(screen).register((current, graphics, mouseX, mouseY, delta) ->
				client.notificationRenderer().renderOverScreen(graphics, current)));
		AttackEntityCallback.EVENT.register((player, level, hand, entity, hitResult) -> {
			if (level.isClientSide() && player == Minecraft.getInstance().player) {
				client.events().post(new AttackEntityEvent(entity));
			}
			return InteractionResult.PASS;
		});
		ResourceLoader.get(PackType.CLIENT_RESOURCES).registerReloader(id("client_resources"),
			(ResourceManagerReloadListener) resourceManager -> client.onResourcesReloaded());
		Log.info("{} {} loaded", ClientInfo.NAME, ClientInfo.version());
	}

	/** The client was called Shadow Visuals before; keep the user's profiles, friends and waypoints. */
	private static void migrateOldConfig(java.nio.file.Path oldDir, java.nio.file.Path newDir) {
		if (java.nio.file.Files.isDirectory(oldDir) && !java.nio.file.Files.exists(newDir)) {
			try {
				java.nio.file.Files.move(oldDir, newDir);
				Log.info("Moved settings from {} to {}", oldDir.getFileName(), newDir.getFileName());
			} catch (java.io.IOException e) {
				Log.warn("Could not move old settings from {}: {}", oldDir, e.toString());
			}
		}
	}

	static Identifier id(String path) {
		return Identifier.fromNamespaceAndPath(ClientInfo.MOD_ID, path);
	}
}
