package com.pitbike.client;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.pitbike.PitbikeMod;
import com.pitbike.entity.PitbikeEntity;
import com.pitbike.entity.Trick;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.LivingEntity;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.RenderLivingEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

/** Moves the rider together with the bike (lean, wheelie, flips) and strikes trick poses. */
@Mod.EventBusSubscriber(modid = PitbikeMod.MOD_ID, value = Dist.CLIENT)
public final class RiderLeanHandler {
    /** Top of the seat in blocks; Superman stretches out from here. */
    private static final float SEAT_TOP = 22.2F / 16.0F;

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
        double height = Mth.lerp(partialTick, rider.yo, rider.getY()) - Mth.lerp(partialTick, bike.yo, bike.getY());
        PoseStack pose = event.getPoseStack();
        pose.pushPose();
        pose.translate(0.0, -height, 0.0);
        pose.mulPose(Axis.YP.rotationDegrees(-yaw));
        BikePose.apply(pose, bike, partialTick, -(float) PitbikeEntity.SEAT_Z);
        if (bike.getClientTrick() == Trick.SUPERMAN) {
            float amount = BikePose.pulse(bike.getTrickProgress(partialTick));
            pose.translate(0.0F, SEAT_TOP + 0.35F * amount, 0.0F);
            pose.mulPose(Axis.XP.rotationDegrees(75.0F * amount));
            pose.translate(0.0F, -SEAT_TOP, 0.0F);
        }
        pose.mulPose(Axis.YP.rotationDegrees(yaw));
        pose.translate(0.0, height, 0.0);

        // The posed arms are drawn by RiderTrickLayer.
        if (event.getRenderer().getModel() instanceof PlayerModel<?> model) {
            RiderTrickLayer.Arms arms = RiderTrickLayer.armsFor(bike.getClientTrick());
            if (arms.right()) {
                model.rightArm.visible = false;
                model.rightSleeve.visible = false;
            }
            if (arms.left()) {
                model.leftArm.visible = false;
                model.leftSleeve.visible = false;
            }
        }
    }

    @SubscribeEvent
    public static void onRenderPost(RenderLivingEvent.Post<?, ?> event) {
        if (event.getEntity().getVehicle() instanceof PitbikeEntity) {
            event.getPoseStack().popPose();
        }
    }
}
