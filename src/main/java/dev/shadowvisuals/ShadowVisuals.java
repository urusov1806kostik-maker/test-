package dev.shadowvisuals;

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
import net.fabricmc.fabric.api.client.rendering.v1.world.WorldRenderEvents;
import net.fabricmc.fabric.api.client.screen.v1.ScreenEvents;
import net.fabricmc.fabric.api.event.player.AttackEntityCallback;
import net.fabricmc.fabric.api.resource.v1.ResourceLoader;
import net.fabricmc.loader.api.FabricLoader;

import dev.shadowvisuals.core.ClientInfo;
import dev.shadowvisuals.core.Log;
import dev.shadowvisuals.event.events.AttackEntityEvent;
import dev.shadowvisuals.event.events.WorldRenderEvent;
import dev.shadowvisuals.render.WorldRenderer3D;

/** Fabric entrypoint: creates the client and connects it to Fabric API callbacks. */
public final class ShadowVisuals implements ClientModInitializer {
	@Override
	public void onInitializeClient() {
		FabricLoader.getInstance().getModContainer(ClientInfo.MOD_ID)
			.ifPresent(container -> ClientInfo.setVersion(container.getMetadata().getVersion().getFriendlyString()));
		ShadowClient client = new ShadowClient(FabricLoader.getInstance().getConfigDir().resolve(ClientInfo.MOD_ID));
		ShadowClient.setInstance(client);
		client.initialize();

		ClientLifecycleEvents.CLIENT_STARTED.register(minecraft -> client.onClientStarted());
		ClientLifecycleEvents.CLIENT_STOPPING.register(minecraft -> client.shutdown());
		ClientTickEvents.START_CLIENT_TICK.register(minecraft -> client.onTick(minecraft, true));
		ClientTickEvents.END_CLIENT_TICK.register(minecraft -> client.onTick(minecraft, false));
		ClientPlayConnectionEvents.JOIN.register((handler, sender, minecraft) -> client.onJoin(minecraft));
		ClientPlayConnectionEvents.DISCONNECT.register((handler, minecraft) -> client.onLeave());

		HudElementRegistry.addLast(id("hud"), client::renderHud);
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

	static Identifier id(String path) {
		return Identifier.fromNamespaceAndPath(ClientInfo.MOD_ID, path);
	}
}
