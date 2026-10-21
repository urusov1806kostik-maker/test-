package com.pitbike.client;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.math.Axis;
import com.pitbike.PitbikeMod;
import com.pitbike.entity.PitbikeEntity;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.EntityRenderer;
import net.minecraft.client.renderer.entity.EntityRendererProvider;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;

public class PitbikeRenderer extends EntityRenderer<PitbikeEntity> {
    private static final ResourceLocation TEXTURE = new ResourceLocation(PitbikeMod.MOD_ID, "textures/entity/pitbike.png");
    private static final ResourceLocation MODEL = new ResourceLocation(PitbikeMod.MOD_ID, "geo/pitbike.json");
    private static final ResourceLocation ANIMATIONS = new ResourceLocation(PitbikeMod.MOD_ID, "animations/pitbike.json");
    /** Played while the bike is ridden, in step with its speed. "ride_forward" is intentionally left unused. */
    private static final String RIDE_ANIMATION = "ride";

    private final BikeModel model;
    private final BikeAnimation rideAnimation;

    public PitbikeRenderer(EntityRendererProvider.Context context) {
        super(context);
        this.shadowRadius = 0.6F;
        this.model = BikeModel.load(context.getResourceManager(), MODEL);
        this.rideAnimation = BikeAnimation.load(context.getResourceManager(), ANIMATIONS).get(RIDE_ANIMATION);
    }

    @Override
    public void render(PitbikeEntity bike, float entityYaw, float partialTick, PoseStack pose,
                       MultiBufferSource buffers, int light) {
        pose.pushPose();
        pose.mulPose(Axis.YP.rotationDegrees(-entityYaw));
        pose.mulPose(Axis.ZP.rotationDegrees(bike.getLean(partialTick)));
        PitbikeRenderer.applyWheelie(pose, bike.getWheelie(partialTick), PitbikeEntity.REAR_CONTACT_Z);
        pose.scale(1.0F / 16.0F, 1.0F / 16.0F, 1.0F / 16.0F);
        int overlay = OverlayTexture.pack(OverlayTexture.u(0.0F), OverlayTexture.v(bike.hurtTime > 0));
        this.model.render(pose, buffers.getBuffer(RenderType.entityCutout(TEXTURE)), light, overlay,
                this.rideAnimation, bike.getRideAnimTime(partialTick));
        pose.popPose();
        super.render(bike, entityYaw, partialTick, pose, buffers, light);
    }

    /** Pitches the front up around the rear wheel contact, {@code pivotZ} blocks along the bike. */
    static void applyWheelie(PoseStack pose, float degrees, float pivotZ) {
        if (degrees > 0.01F) {
            pose.translate(0.0F, 0.0F, pivotZ);
            pose.mulPose(Axis.XP.rotationDegrees(-degrees));
            pose.translate(0.0F, 0.0F, -pivotZ);
        }
    }

    @Override
    public ResourceLocation getTextureLocation(PitbikeEntity bike) {
        return TEXTURE;
    }
}
