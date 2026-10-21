package com.pitbike.client;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.pitbike.entity.PitbikeEntity;
import com.pitbike.entity.Trick;
import net.minecraft.client.model.PlayerModel;
import net.minecraft.client.model.geom.ModelPart;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.entity.LivingEntityRenderer;
import net.minecraft.client.renderer.entity.RenderLayerParent;
import net.minecraft.client.renderer.entity.layers.RenderLayer;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.player.PlayerModelPart;
import org.jetbrains.annotations.Nullable;

/** Draws the rider's arms in trick poses (vanilla re-poses them every frame, so they are drawn here instead). */
public class RiderTrickLayer extends RenderLayer<AbstractClientPlayer, PlayerModel<AbstractClientPlayer>> {
    public record Arms(boolean right, boolean left) {
    }

    private static final Arms NONE = new Arms(false, false);

    public RiderTrickLayer(RenderLayerParent<AbstractClientPlayer, PlayerModel<AbstractClientPlayer>> parent) {
        super(parent);
    }

    public static Arms armsFor(@Nullable Trick trick) {
        if (trick == null) {
            return NONE;
        }
        return switch (trick) {
            case ONE_HANDER -> new Arms(true, false);
            case NO_HANDER, SUPERMAN -> new Arms(true, true);
            default -> NONE;
        };
    }

    @Override
    public void render(PoseStack pose, MultiBufferSource buffers, int light, AbstractClientPlayer player,
                       float limbSwing, float limbSwingAmount, float partialTick, float ageInTicks,
                       float netHeadYaw, float headPitch) {
        if (!(player.getVehicle() instanceof PitbikeEntity bike)) {
            return;
        }
        Trick trick = bike.getClientTrick();
        Arms arms = armsFor(trick);
        if (!arms.right() && !arms.left()) {
            return;
        }
        float amount = BikePose.pulse(bike.getTrickProgress(partialTick));
        PlayerModel<AbstractClientPlayer> model = this.getParentModel();
        VertexConsumer consumer = buffers.getBuffer(RenderType.entityTranslucent(player.getSkinTextureLocation()));
        int overlay = LivingEntityRenderer.getOverlayCoords(player, 0.0F);

        // Model space: x = right arm side is negative, positive zRot swings the right arm outwards.
        float raise = trick == Trick.ONE_HANDER ? -0.2F : -2.9F;
        float spread = trick == Trick.ONE_HANDER ? 1.4F : 0.25F;
        if (arms.right()) {
            this.renderArm(pose, consumer, light, overlay, model.rightArm, model.rightSleeve,
                    player.isModelPartShown(PlayerModelPart.RIGHT_SLEEVE), amount, raise, spread);
        }
        if (arms.left()) {
            this.renderArm(pose, consumer, light, overlay, model.leftArm, model.leftSleeve,
                    player.isModelPartShown(PlayerModelPart.LEFT_SLEEVE), amount, raise, -spread);
        }
    }

    private void renderArm(PoseStack pose, VertexConsumer consumer, int light, int overlay, ModelPart arm,
                           ModelPart sleeve, boolean showSleeve, float amount, float xRot, float zRot) {
        arm.visible = true;
        arm.xRot = Mth.lerp(amount, arm.xRot, xRot);
        arm.yRot = Mth.lerp(amount, arm.yRot, 0.0F);
        arm.zRot = Mth.lerp(amount, arm.zRot, zRot);
        arm.render(pose, consumer, light, overlay);
        if (showSleeve) {
            sleeve.copyFrom(arm);
            sleeve.visible = true;
            sleeve.render(pose, consumer, light, overlay);
        }
    }
}
