package com.pitbike.client;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.pitbike.entity.PitbikeEntity;
import com.pitbike.entity.Trick;
import org.joml.Quaternionf;

/** Whole-bike motion (lean, wheelie, flips) shared by the bike and its rider. */
public final class BikePose {
    /** Height of the bike's middle, in blocks; flips and spins turn around it. */
    private static final float CENTER_Y = 0.75F;

    private BikePose() {
    }

    /**
     * Applies the bike motion in a frame aligned with the bike, standing on its ground point.
     * {@code zOffset} is where the bike's origin is along its length, relative to the pose origin.
     */
    public static void apply(PoseStack pose, PitbikeEntity bike, float partialTick, float zOffset) {
        pose.mulPose(Axis.ZP.rotationDegrees(bike.getLean(partialTick)));

        float wheelie = bike.getWheelie(partialTick);
        if (wheelie > 0.01F) {
            rotateAround(pose, Axis.XP.rotationDegrees(-wheelie), 0.0F, PitbikeEntity.REAR_CONTACT_Z + zOffset);
        }

        Trick trick = bike.getClientTrick();
        float progress = ease(bike.getTrickProgress(partialTick));
        if (trick == Trick.BACKFLIP) {
            rotateAround(pose, Axis.XP.rotationDegrees(-360.0F * progress), CENTER_Y, zOffset);
        } else if (trick == Trick.SPIN) {
            rotateAround(pose, Axis.YP.rotationDegrees(360.0F * progress), 0.0F, zOffset);
        }
    }

    private static void rotateAround(PoseStack pose, Quaternionf rotation, float y, float z) {
        pose.translate(0.0F, y, z);
        pose.mulPose(rotation);
        pose.translate(0.0F, -y, -z);
    }

    /** Smooth start and finish. */
    public static float ease(float t) {
        return t * t * (3.0F - 2.0F * t);
    }

    /** 0 -> 1 -> 0 over a trick, for poses that are struck and released. */
    public static float pulse(float t) {
        return Math.min(1.0F, (float) Math.sin(t * Math.PI) * 2.0F);
    }
}
