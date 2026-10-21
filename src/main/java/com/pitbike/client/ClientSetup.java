package com.pitbike.client;

import com.pitbike.ModEntities;
import com.pitbike.PitbikeMod;
import com.pitbike.entity.PitbikeEntity;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.entity.player.PlayerRenderer;
import net.minecraft.network.chat.Component;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.client.event.RegisterGuiOverlaysEvent;
import net.minecraftforge.client.event.RegisterKeyMappingsEvent;
import net.minecraftforge.client.gui.overlay.VanillaGuiOverlay;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = PitbikeMod.MOD_ID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public final class ClientSetup {
    private ClientSetup() {
    }

    @SubscribeEvent
    public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.registerEntityRenderer(ModEntities.PITBIKE.get(), PitbikeRenderer::new);
    }

    @SubscribeEvent
    public static void registerKeys(RegisterKeyMappingsEvent event) {
        PitbikeKeys.TRICKS.values().forEach(event::register);
    }

    @SubscribeEvent
    public static void addLayers(EntityRenderersEvent.AddLayers event) {
        for (String skin : event.getSkins()) {
            if (event.getSkin(skin) instanceof PlayerRenderer renderer) {
                renderer.addLayer(new RiderTrickLayer(renderer));
            }
        }
    }

    @SubscribeEvent
    public static void registerOverlays(RegisterGuiOverlaysEvent event) {
        event.registerAbove(VanillaGuiOverlay.HOTBAR.id(), "speedometer", (gui, graphics, partialTick, width, height) -> {
            Minecraft mc = Minecraft.getInstance();
            if (mc.options.hideGui || !(mc.player != null && mc.player.getVehicle() instanceof PitbikeEntity bike)) {
                return;
            }
            int kmh = Math.round(Math.abs(bike.getDrivingSpeed()) * 20.0F * 3.6F);
            Component text = Component.translatable("hud.pitbike.speed", kmh);
            graphics.drawString(mc.font, text, width / 2 + 96, height - 20, 0xFFFFFF);
        });
    }
}
