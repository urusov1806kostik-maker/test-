package dev.shadowvisuals.modules.visual;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.ShapeRenderer;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.client.renderer.state.BlockOutlineRenderState;
import net.minecraft.core.BlockPos;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import net.fabricmc.fabric.api.client.rendering.v1.world.WorldRenderContext;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.WorldRenderer3D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Selection box and block overlay for the targeted block: configurable outline color and width plus an
 * optional translucent fill. Uses the block's real shape, replacing the vanilla outline only while enabled.
 */
public final class BlockOutline extends Module {
	private final ColorSetting outline = settings().add(new ColorSetting("outline_color", 0xE68B7CF6, true));
	private final NumberSetting width = settings().add(new NumberSetting("line_width", 2.0, 1.0, 6.0, 0.5));
	private final BooleanSetting overlay = settings().add(new BooleanSetting("block_overlay", true));
	private final ColorSetting fillColor = settings().add(new ColorSetting("overlay_color", 0x308B7CF6, true)).dependsOn(overlay);

	public BlockOutline() {
		super("block_outline", Category.VISUAL);
	}

	/** Called from the Fabric block-outline event; returns false to suppress the vanilla outline. */
	public boolean render(WorldRenderContext context, BlockOutlineRenderState state) {
		Minecraft minecraft = Minecraft.getInstance();
		Vec3 camera = context.worldState().cameraRenderState.pos;
		BlockPos pos = state.pos();
		PoseStack poses = context.matrices();
		VertexConsumer lines = context.consumers().getBuffer(RenderTypes.lines());
		ShapeRenderer.renderShape(poses, lines, state.shape(), pos.getX() - camera.x, pos.getY() - camera.y, pos.getZ() - camera.z,
			outline.color(), width.getFloat());
		if (overlay.get() && !state.shape().isEmpty()) {
			AABB bounds = state.shape().bounds().move(pos).inflate(0.002);
			WorldRenderer3D.Frame frame = new WorldRenderer3D.Frame(poses, context.consumers(), camera,
				minecraft.getDeltaTracker().getGameTimeDeltaPartialTick(false));
			WorldRenderer3D.boxFilled(frame, bounds, ColorUtil.withAlpha(fillColor.color(), ColorUtil.alpha(fillColor.color())), false);
		}
		return false;
	}
}
