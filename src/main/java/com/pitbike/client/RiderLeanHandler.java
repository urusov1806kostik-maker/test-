package com.pitbike.client;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.pitbike.PitbikeMod;
import com.pitbike.entity.PitbikeEntity;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.LivingEntity;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.RenderLivingEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

/** Tilts the rider together with the bike when it leans into a turn. */
@Mod.EventBusSubscriber(modid = PitbikeMod.MOD_ID, value = Dist.CLIENT)
public final class RiderLeanHandler {
    private RiderLeanHandler() {
    }

    // Lowest priority: once the pose is pushed nobody else may cancel the render, or Post would never pop it.
    @SubscribeEvent(priority = EventPriority.LOWEST)
    public static void onRenderPre(RenderLivingEvent.Pre<?, ?> event) {
        LivingEntity rider = event.getEntity();
        if (!(rider.getVehicle() instanceof PitbikeEntity bike)) {
            return;
        }
        float partialTick = event.getPartialTick();
        float yaw = Mth.rotLerp(partialTick, bike.yRotO, bike.getYRot());
        // Roll around the bike's own ground line, so the rider stays on the seat.
        double height = Mth.lerp(partialTick, rider.yo, rider.getY()) - Mth.lerp(partialTick, bike.yo, bike.getY());
        PoseStack pose = event.getPoseStack();
        pose.pushPose();
        pose.translate(0.0, -height, 0.0);
        pose.mulPose(Axis.YP.rotationDegrees(-yaw));
        pose.mulPose(Axis.ZP.rotationDegrees(bike.getLean(partialTick)));
        pose.mulPose(Axis.YP.rotationDegrees(yaw));
        pose.translate(0.0, height, 0.0);
    }

    @SubscribeEvent
    public static void onRenderPost(RenderLivingEvent.Post<?, ?> event) {
        if (event.getEntity().getVehicle() instanceof PitbikeEntity) {
            event.getPoseStack().popPose();
        }
    }
}
