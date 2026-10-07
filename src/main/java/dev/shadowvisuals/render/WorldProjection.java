package dev.shadowvisuals.render;

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
}
