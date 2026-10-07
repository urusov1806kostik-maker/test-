package dev.shadowvisuals.render;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.rendertype.RenderSetup;
import net.minecraft.client.renderer.rendertype.RenderType;
import net.minecraft.client.renderer.rendertype.RenderTypes;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

/**
 * Centralized 3D primitives for world visuals. All methods take camera-relative coordinates through the
 * {@link Frame} so callers never deal with matrix bookkeeping; render types come from vanilla or from
 * {@link ShadowPipelines}, which keeps blend/depth state inside the pipeline system.
 */
public final class WorldRenderer3D {
	public static final RenderType LINES_SEE_THROUGH = RenderType.create("shadowvisuals_lines_see_through",
		RenderSetup.builder(ShadowPipelines.WORLD_LINES_SEE_THROUGH).createRenderSetup());
	public static final RenderType QUADS = RenderType.create("shadowvisuals_quads",
		RenderSetup.builder(ShadowPipelines.WORLD_QUADS).sortOnUpload().createRenderSetup());
	public static final RenderType QUADS_SEE_THROUGH = RenderType.create("shadowvisuals_quads_see_through",
		RenderSetup.builder(ShadowPipelines.WORLD_QUADS_SEE_THROUGH).sortOnUpload().createRenderSetup());

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
}
