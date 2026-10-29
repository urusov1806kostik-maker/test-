package dev.nyxveravisuals.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.gui.Font;
import net.minecraft.client.renderer.LightTexture;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.rendertype.RenderSetup;
import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.render.font.WorldText;

/**
 * Centralized 3D primitives for world visuals. All methods take camera-relative coordinates through the
 * {@link Frame} so callers never deal with matrix bookkeeping; render types come from vanilla or from
 * {@link NyxveraPipelines}, which keeps blend/depth state inside the pipeline system.
 */
public final class WorldRenderer3D {
	public static final RenderType LINES_SEE_THROUGH = RenderType.create("nyxveravisuals_lines_see_through",
		RenderSetup.builder(NyxveraPipelines.WORLD_LINES_SEE_THROUGH).createRenderSetup());
	public static final RenderType QUADS = RenderType.create("nyxveravisuals_quads",
		RenderSetup.builder(NyxveraPipelines.WORLD_QUADS).sortOnUpload().createRenderSetup());
	public static final RenderType QUADS_SEE_THROUGH = RenderType.create("nyxveravisuals_quads_see_through",
		RenderSetup.builder(NyxveraPipelines.WORLD_QUADS_SEE_THROUGH).sortOnUpload().createRenderSetup());

	private WorldRenderer3D() {
	}

	/** Per-frame drawing context: pose stack, buffers and camera position. */
	public record Frame(PoseStack poses, MultiBufferSource buffers, Vec3 camera, float partialTick) {
		public VertexConsumer lines(boolean throughWalls) {
			return buffers.getBuffer(throughWalls ? LINES_SEE_THROUGH : RenderTypes.lines());
		}

		public VertexConsumer quads(boolean throughWalls) {
			return buffers.getBuffer(throughWalls ? QUADS_SEE_THROUGH : QUADS);
		}
	}

	public static void boxOutline(Frame frame, AABB box, int color, float lineWidth, boolean throughWalls) {
		VertexConsumer consumer = frame.lines(throughWalls);
		PoseStack.Pose pose = frame.poses().last();
		float x0 = (float) (box.minX - frame.camera().x);
		float y0 = (float) (box.minY - frame.camera().y);
		float z0 = (float) (box.minZ - frame.camera().z);
		float x1 = (float) (box.maxX - frame.camera().x);
		float y1 = (float) (box.maxY - frame.camera().y);
		float z1 = (float) (box.maxZ - frame.camera().z);
		line(consumer, pose, x0, y0, z0, x1, y0, z0, color, lineWidth);
		line(consumer, pose, x0, y0, z1, x1, y0, z1, color, lineWidth);
		line(consumer, pose, x0, y1, z0, x1, y1, z0, color, lineWidth);
		line(consumer, pose, x0, y1, z1, x1, y1, z1, color, lineWidth);
		line(consumer, pose, x0, y0, z0, x0, y1, z0, color, lineWidth);
		line(consumer, pose, x1, y0, z0, x1, y1, z0, color, lineWidth);
		line(consumer, pose, x0, y0, z1, x0, y1, z1, color, lineWidth);
		line(consumer, pose, x1, y0, z1, x1, y1, z1, color, lineWidth);
		line(consumer, pose, x0, y0, z0, x0, y0, z1, color, lineWidth);
		line(consumer, pose, x1, y0, z0, x1, y0, z1, color, lineWidth);
		line(consumer, pose, x0, y1, z0, x0, y1, z1, color, lineWidth);
		line(consumer, pose, x1, y1, z0, x1, y1, z1, color, lineWidth);
	}

	public static void line(VertexConsumer consumer, PoseStack.Pose pose, float x0, float y0, float z0,
		float x1, float y1, float z1, int color, float width) {
		float nx = x1 - x0;
		float ny = y1 - y0;
		float nz = z1 - z0;
		float length = (float) Math.sqrt(nx * nx + ny * ny + nz * nz);
		if (length < 1e-4f) {
			return;
		}
		nx /= length;
		ny /= length;
		nz /= length;
		consumer.addVertex(pose, x0, y0, z0).setColor(color).setNormal(pose, nx, ny, nz).setLineWidth(width);
		consumer.addVertex(pose, x1, y1, z1).setColor(color).setNormal(pose, nx, ny, nz).setLineWidth(width);
	}

	/** Line between two world positions. */
	public static void worldLine(Frame frame, Vec3 from, Vec3 to, int color, float width, boolean throughWalls) {
		Vec3 camera = frame.camera();
		line(frame.lines(throughWalls), frame.poses().last(),
			(float) (from.x - camera.x), (float) (from.y - camera.y), (float) (from.z - camera.z),
			(float) (to.x - camera.x), (float) (to.y - camera.y), (float) (to.z - camera.z), color, width);
	}

	public static void boxFilled(Frame frame, AABB box, int color, boolean throughWalls) {
		VertexConsumer consumer = frame.quads(throughWalls);
		PoseStack.Pose pose = frame.poses().last();
		float x0 = (float) (box.minX - frame.camera().x);
		float y0 = (float) (box.minY - frame.camera().y);
		float z0 = (float) (box.minZ - frame.camera().z);
		float x1 = (float) (box.maxX - frame.camera().x);
		float y1 = (float) (box.maxY - frame.camera().y);
		float z1 = (float) (box.maxZ - frame.camera().z);
		quad(consumer, pose, x0, y0, z0, x1, y0, z0, x1, y1, z0, x0, y1, z0, color);
		quad(consumer, pose, x1, y0, z1, x0, y0, z1, x0, y1, z1, x1, y1, z1, color);
		quad(consumer, pose, x0, y0, z1, x0, y0, z0, x0, y1, z0, x0, y1, z1, color);
		quad(consumer, pose, x1, y0, z0, x1, y0, z1, x1, y1, z1, x1, y1, z0, color);
		quad(consumer, pose, x0, y1, z0, x1, y1, z0, x1, y1, z1, x0, y1, z1, color);
		quad(consumer, pose, x0, y0, z1, x1, y0, z1, x1, y0, z0, x0, y0, z0, color);
	}

	public static void quad(VertexConsumer consumer, PoseStack.Pose pose,
		float ax, float ay, float az, float bx, float by, float bz,
		float cx, float cy, float cz, float dx, float dy, float dz, int color) {
		consumer.addVertex(pose, ax, ay, az).setColor(color);
		consumer.addVertex(pose, bx, by, bz).setColor(color);
		consumer.addVertex(pose, cx, cy, cz).setColor(color);
		consumer.addVertex(pose, dx, dy, dz).setColor(color);
	}

	/**
	 * Flat horizontal ring at world height {@code y}; {@code innerColor}/{@code outerColor} give a soft
	 * gradient across the band. {@code segments} trades smoothness for vertex count.
	 */
	public static void ring(Frame frame, double centerX, double y, double centerZ, float innerRadius, float outerRadius,
		int innerColor, int outerColor, int segments, boolean throughWalls) {
		VertexConsumer consumer = frame.quads(throughWalls);
		PoseStack.Pose pose = frame.poses().last();
		float cx = (float) (centerX - frame.camera().x);
		float cy = (float) (y - frame.camera().y);
		float cz = (float) (centerZ - frame.camera().z);
		double step = Math.PI * 2 / segments;
		for (int i = 0; i < segments; i++) {
			float cos0 = (float) Math.cos(i * step);
			float sin0 = (float) Math.sin(i * step);
			float cos1 = (float) Math.cos((i + 1) * step);
			float sin1 = (float) Math.sin((i + 1) * step);
			consumer.addVertex(pose, cx + cos0 * innerRadius, cy, cz + sin0 * innerRadius).setColor(innerColor);
			consumer.addVertex(pose, cx + cos0 * outerRadius, cy, cz + sin0 * outerRadius).setColor(outerColor);
			consumer.addVertex(pose, cx + cos1 * outerRadius, cy, cz + sin1 * outerRadius).setColor(outerColor);
			consumer.addVertex(pose, cx + cos1 * innerRadius, cy, cz + sin1 * innerRadius).setColor(innerColor);
		}
	}

	/** Font units per block at scale 1; the same density as vanilla name tags. */
	public static final float TEXT_UNIT = 0.025f;
	/** Extrusion length in font units at depth 1. */
	private static final float TEXT_DEPTH_UNITS = 4f;
	/** Spacing between extrusion layers in font units; small enough that the sides read as solid. */
	private static final float TEXT_LAYER_STEP = 0.45f;
	/** Client-font size in font units, matched to the Minecraft font's 9-unit line. */
	private static final float TEXT_SIZE = 9f;
	private static final FontManager.Weight TEXT_WEIGHT = FontManager.Weight.SEMIBOLD;

	/**
	 * Solid 3D text standing upright at a world position and turned towards the camera around the vertical
	 * axis. The letters are extruded backwards (and slightly down-right, so the volume is visible even when
	 * looked at head-on) with progressively darker layers; no outline and no background plate. {@code depth}
	 * 0 draws flat text. Rows use the client font (Inter) and fall back to the Minecraft font for rows it cannot
	 * draw. Colors are ARGB; nearly transparent text is skipped because the vanilla font treats it as opaque.
	 */
	public static void text3d(Frame frame, FontManager fonts, Font font, java.util.List<String> rows, double x, double y, double z,
		float scale, int color, float depth, boolean throughWalls) {
		if (rows.isEmpty() || (color >>> 24) < 6) {
			return;
		}
		double dx = x - frame.camera().x;
		double dy = y - frame.camera().y;
		double dz = z - frame.camera().z;
		// Same rotation the camera uses for a yaw looking at the text, without pitch, so the text stays upright.
		float yawToText = (float) Math.atan2(-dx, dz);
		PoseStack poses = frame.poses();
		poses.pushPose();
		poses.translate(dx, dy, dz);
		poses.mulPose(new org.joml.Quaternionf().rotationY((float) Math.PI - yawToText));
		float unit = TEXT_UNIT * scale;
		poses.scale(unit, -unit, unit);
		int count = rows.size();
		boolean[] custom = new boolean[count];
		float[] widths = new float[count];
		for (int i = 0; i < count; i++) {
			String row = rows.get(i);
			custom[i] = WorldText.canDraw(fonts, row, TEXT_WEIGHT);
			widths[i] = custom[i] ? WorldText.width(fonts, row, TEXT_SIZE, TEXT_WEIGHT) : font.width(row);
		}
		float lineHeight = font.lineHeight + 1;
		float top = -count * lineHeight / 2f;
		int layers = depth <= 0 ? 0 : Math.clamp(Math.round(depth * TEXT_DEPTH_UNITS / TEXT_LAYER_STEP), 2, 16);
		float step = layers == 0 ? 0 : depth * TEXT_DEPTH_UNITS / layers;
		for (int layer = layers; layer >= 0; layer--) {
			// Back layers first; the front face is drawn last at full brightness.
			float shade = layer == 0 ? 1f : 0.42f + 0.28f * (1f - (float) layer / layers);
			int layerColor = layer == 0 ? color : (color & 0xFF000000)
				| Math.round(((color >> 16) & 0xFF) * shade) << 16
				| Math.round(((color >> 8) & 0xFF) * shade) << 8
				| Math.round((color & 0xFF) * shade);
			poses.pushPose();
			poses.translate(layer * step * 0.3f, layer * step * 0.3f, -layer * step);
			PoseStack.Pose pose = poses.last();
			for (int i = 0; i < count; i++) {
				float left = -widths[i] / 2f;
				float rowY = top + i * lineHeight;
				if (custom[i]) {
					WorldText.draw(fonts, frame.buffers(), pose, rows.get(i), left, rowY, TEXT_SIZE, TEXT_WEIGHT, layerColor, throughWalls);
				} else {
					font.drawInBatch(rows.get(i), left, rowY, layerColor, false, pose.pose(), frame.buffers(),
						throughWalls ? Font.DisplayMode.SEE_THROUGH : Font.DisplayMode.NORMAL, 0, LightTexture.FULL_BRIGHT);
				}
			}
			poses.popPose();
		}
		poses.popPose();
	}

	/** Width of a {@link #text3d} row in font units, for wrapping. */
	public static float textWidth(FontManager fonts, Font font, String text) {
		return WorldText.canDraw(fonts, text, TEXT_WEIGHT) ? WorldText.width(fonts, text, TEXT_SIZE, TEXT_WEIGHT) : font.width(text);
	}

	/** Splits {@code text} at spaces into rows no wider than {@code maxWidth} font units. */
	public static java.util.List<String> wrap(FontManager fonts, Font font, String text, float maxWidth) {
		java.util.List<String> rows = new java.util.ArrayList<>(2);
		StringBuilder row = new StringBuilder();
		for (String word : text.split(" ")) {
			if (word.isEmpty()) {
				continue;
			}
			String candidate = row.isEmpty() ? word : row + " " + word;
			if (!row.isEmpty() && textWidth(fonts, font, candidate) > maxWidth) {
				rows.add(row.toString());
				row.setLength(0);
				row.append(word);
			} else {
				row.setLength(0);
				row.append(candidate);
			}
		}
		if (!row.isEmpty()) {
			rows.add(row.toString());
		}
		return rows;
	}
}
