package dev.nyxveravisuals.render;

import org.joml.Matrix4f;
import org.joml.Matrix4fc;
import org.joml.Vector4f;

import net.minecraft.client.Minecraft;
import net.minecraft.world.phys.Vec3;

/**
 * World-to-screen projection using the exact matrices of the last rendered world frame (captured by a
 * {@code LevelRenderer} mixin), so nametags and 2D ESP line up with the 3D scene including FOV, bobbing and
 * zoom. Reuses its vectors: projecting never allocates.
 */
public final class WorldProjection {
	private final Matrix4f viewProjection = new Matrix4f();
	private final Vector4f scratch = new Vector4f();
	private double cameraX;
	private double cameraY;
	private double cameraZ;
	private boolean valid;

	/** Screen position result in GUI units; {@code depth} grows with distance from the camera. */
	public static final class ScreenPoint {
		public float x;
		public float y;
		public float depth;
	}

	public void capture(Matrix4fc view, Matrix4fc projection, Vec3 camera) {
		projection.mul(view, viewProjection);
		cameraX = camera.x;
		cameraY = camera.y;
		cameraZ = camera.z;
		valid = true;
	}

	public void invalidate() {
		valid = false;
	}

	public boolean isValid() {
		return valid;
	}

	public double cameraX() {
		return cameraX;
	}

	public double cameraY() {
		return cameraY;
	}

	public double cameraZ() {
		return cameraZ;
	}

	/** Projects a world position; returns false when it is behind the camera or no frame was captured. */
	public boolean project(double x, double y, double z, ScreenPoint out) {
		if (!valid) {
			return false;
		}
		scratch.set((float) (x - cameraX), (float) (y - cameraY), (float) (z - cameraZ), 1f);
		viewProjection.transform(scratch);
		if (scratch.w <= 0.01f) {
			return false;
		}
		float ndcX = scratch.x / scratch.w;
		float ndcY = scratch.y / scratch.w;
		var window = Minecraft.getInstance().getWindow();
		out.x = (ndcX * 0.5f + 0.5f) * window.getGuiScaledWidth();
		out.y = (1f - (ndcY * 0.5f + 0.5f)) * window.getGuiScaledHeight();
		out.depth = scratch.w;
		return true;
	}

	private final ScreenPoint corner = new ScreenPoint();

	/**
	 * Projects an axis-aligned box and writes its screen bounds {@code minX, minY, maxX, maxY} into
	 * {@code out}. Returns false if any corner is behind the camera (the box is then not drawn).
	 */
	public boolean projectBox(double minX, double minY, double minZ, double maxX, double maxY, double maxZ, float[] out) {
		float left = Float.MAX_VALUE;
		float top = Float.MAX_VALUE;
		float right = -Float.MAX_VALUE;
		float bottom = -Float.MAX_VALUE;
		for (int i = 0; i < 8; i++) {
			double x = (i & 1) == 0 ? minX : maxX;
			double y = (i & 2) == 0 ? minY : maxY;
			double z = (i & 4) == 0 ? minZ : maxZ;
			if (!project(x, y, z, corner)) {
				return false;
			}
			left = Math.min(left, corner.x);
			top = Math.min(top, corner.y);
			right = Math.max(right, corner.x);
			bottom = Math.max(bottom, corner.y);
		}
		out[0] = left;
		out[1] = top;
		out[2] = right;
		out[3] = bottom;
		return true;
	}
}
