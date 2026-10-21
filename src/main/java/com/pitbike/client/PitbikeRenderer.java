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
        BikePose.apply(pose, bike, partialTick, 0.0F);
        pose.scale(1.0F / 16.0F, 1.0F / 16.0F, 1.0F / 16.0F);
        int overlay = OverlayTexture.pack(OverlayTexture.u(0.0F), OverlayTexture.v(bike.hurtTime > 0));
        this.model.render(pose, buffers.getBuffer(RenderType.entityCutout(TEXTURE)), light, overlay,
                this.rideAnimation, bike.getRideAnimTime(partialTick));
        pose.popPose();
        super.render(bike, entityYaw, partialTick, pose, buffers, light);
    }

    @Override
    public ResourceLocation getTextureLocation(PitbikeEntity bike) {
        return TEXTURE;
    }
}
