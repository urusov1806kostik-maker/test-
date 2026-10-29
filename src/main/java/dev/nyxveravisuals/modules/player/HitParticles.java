package dev.nyxveravisuals.modules.player;

import java.util.concurrent.ThreadLocalRandom;

import org.joml.Vector3fc;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.Camera;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

import dev.nyxveravisuals.animation.AnimationClock;
import dev.nyxveravisuals.event.events.AttackEntityEvent;
import dev.nyxveravisuals.event.events.WorldLeaveEvent;
import dev.nyxveravisuals.event.events.WorldRenderEvent;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.WorldRenderer3D;
import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.IntSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * Small glowing particles that burst from entities you hit. Uses its own particle pool (structure of
 * arrays, hard capacity) instead of vanilla particles, so it cannot be disabled by particle settings, never
 * allocates while running and simulates with frame delta time (identical motion at any FPS).
 */
public final class HitParticles extends Module {
	public enum Shape {
		SQUARE,
		DIAMOND,
		SPARK
	}

	private static final int CAPACITY = 384;

	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFF8B7CF6, true));
	private final ModeSetting<Shape> shape = settings().add(new ModeSetting<>("shape", Shape.DIAMOND));
	private final IntSetting count = settings().add(new IntSetting("count", 14, 2, 48));
	private final NumberSetting size = settings().add(new NumberSetting("size", 0.08, 0.02, 0.3, 0.01).suffix("m"));
	private final NumberSetting lifetime = settings().add(new NumberSetting("lifetime", 1.0, 0.2, 3.0, 0.1).suffix("s"));
	private final NumberSetting speed = settings().add(new NumberSetting("speed", 2.5, 0.5, 8.0, 0.1));
	private final NumberSetting gravity = settings().add(new NumberSetting("gravity", 6.0, 0.0, 20.0, 0.5));

	private final float[] x = new float[CAPACITY];
	private final float[] y = new float[CAPACITY];
	private final float[] z = new float[CAPACITY];
	private final float[] vx = new float[CAPACITY];
	private final float[] vy = new float[CAPACITY];
	private final float[] vz = new float[CAPACITY];
	private final float[] age = new float[CAPACITY];
	private final float[] life = new float[CAPACITY];
	private final float[] hue = new float[CAPACITY];
	/** Particle positions are relative to this origin so float precision holds far from world zero. */
	private double originX;
	private double originY;
	private double originZ;
	private int alive;
	private final BlockPos.MutableBlockPos probe = new BlockPos.MutableBlockPos();

	public HitParticles() {
		super("hit_particles", Category.PLAYER);
		on(AttackEntityEvent.class, event -> burst(event.target()));
		on(WorldRenderEvent.class, this::render);
		on(WorldLeaveEvent.class, event -> alive = 0);
	}

	@Override
	protected void onDisable() {
		alive = 0;
	}

	private void burst(Entity target) {
		if (!(target instanceof LivingEntity) || !target.isAlive()) {
			return;
		}
		AABB box = target.getBoundingBox();
		Vec3 center = box.getCenter();
		if (alive == 0) {
			originX = center.x;
			originY = center.y;
			originZ = center.z;
		}
		ThreadLocalRandom random = ThreadLocalRandom.current();
		int amount = count.get();
		float baseSpeed = speed.getFloat();
		float maxLife = lifetime.getFloat();
		for (int n = 0; n < amount; n++) {
			int i = alive < CAPACITY ? alive++ : random.nextInt(CAPACITY);
			x[i] = (float) (center.x - originX + (random.nextDouble() - 0.5) * box.getXsize() * 0.6);
			y[i] = (float) (center.y - originY + (random.nextDouble() - 0.5) * box.getYsize() * 0.6);
			z[i] = (float) (center.z - originZ + (random.nextDouble() - 0.5) * box.getZsize() * 0.6);
			// Random direction biased upwards so the burst reads as an impact.
			double theta = random.nextDouble() * Math.PI * 2;
			double phi = Math.acos(random.nextDouble() * 1.6 - 0.6);
			float magnitude = baseSpeed * (0.5f + random.nextFloat() * 0.7f);
			vx[i] = (float) (Math.sin(phi) * Math.cos(theta)) * magnitude;
			vy[i] = (float) Math.cos(phi) * magnitude;
			vz[i] = (float) (Math.sin(phi) * Math.sin(theta)) * magnitude;
			age[i] = 0f;
			life[i] = maxLife * (0.65f + random.nextFloat() * 0.35f);
			hue[i] = random.nextFloat() * 0.25f;
		}
	}

	private void simulate(float delta, Minecraft minecraft) {
		float drag = (float) Math.pow(0.35, delta);
		float fall = gravity.getFloat() * delta;
		for (int i = 0; i < alive; i++) {
			age[i] += delta;
			if (age[i] >= life[i]) {
				// Swap-remove keeps the live particles packed at the front of the arrays.
				int last = --alive;
				copy(last, i);
				i--;
				continue;
			}
			vy[i] -= fall;
			vx[i] *= drag;
			vy[i] *= drag;
			vz[i] *= drag;
			float nextY = y[i] + vy[i] * delta;
			if (vy[i] < 0 && minecraft.level != null) {
				probe.set(originX + x[i], originY + nextY, originZ + z[i]);
				if (!minecraft.level.getBlockState(probe).getCollisionShape(minecraft.level, probe).isEmpty()) {
					vy[i] = -vy[i] * 0.45f;
					vx[i] *= 0.7f;
					vz[i] *= 0.7f;
					nextY = y[i];
				}
			}
			x[i] += vx[i] * delta;
			y[i] = nextY;
			z[i] += vz[i] * delta;
		}
	}

	private void copy(int from, int to) {
		x[to] = x[from];
		y[to] = y[from];
		z[to] = z[from];
		vx[to] = vx[from];
		vy[to] = vy[from];
		vz[to] = vz[from];
		age[to] = age[from];
		life[to] = life[from];
		hue[to] = hue[from];
	}

	private void render(WorldRenderEvent event) {
		if (alive == 0) {
			return;
		}
		Minecraft minecraft = Minecraft.getInstance();
		simulate(AnimationClock.global().delta(), minecraft);
		if (alive == 0) {
			return;
		}
		WorldRenderer3D.Frame frame = event.frame();
		Camera camera = minecraft.gameRenderer.getMainCamera();
		Vector3fc up = camera.upVector();
		Vector3fc left = camera.leftVector();
		VertexConsumer consumer = frame.quads(false);
		PoseStack.Pose pose = frame.poses().last();
		float ox = (float) (originX - frame.camera().x);
		float oy = (float) (originY - frame.camera().y);
		float oz = (float) (originZ - frame.camera().z);
		float half = size.getFloat() / 2f;
		Shape style = shape.get();
		boolean diamond = style == Shape.DIAMOND;
		for (int i = 0; i < alive; i++) {
			float t = age[i] / life[i];
			float fade = 1f - t * t;
			int base = color.color(hue[i]);
			int core = ColorUtil.withAlpha(base, Math.round(ColorUtil.alpha(base) * fade));
			int glow = ColorUtil.withAlpha(base, Math.round(ColorUtil.alpha(base) * fade * 0.22f));
			float px = ox + x[i];
			float py = oy + y[i];
			float pz = oz + z[i];
			float s = half * (1f - t * 0.5f);
			if (style == Shape.SPARK) {
				spark(consumer, pose, px, py, pz, vx[i], vy[i], vz[i], s * 0.7f, core);
				continue;
			}
			billboard(consumer, pose, px, py, pz, up, left, s * 2.6f, diamond, glow);
			billboard(consumer, pose, px, py, pz, up, left, s, diamond, core);
		}
	}

	/**
	 * Streak from the particle back along its velocity, widened perpendicular to both the motion and the view
	 * direction so it always faces the camera; the tail fades out.
	 */
	private static void spark(VertexConsumer consumer, PoseStack.Pose pose, float px, float py, float pz,
		float velocityX, float velocityY, float velocityZ, float half, int color) {
		float speed = (float) Math.sqrt(velocityX * velocityX + velocityY * velocityY + velocityZ * velocityZ);
		if (speed < 1e-3f) {
			return;
		}
		// Camera-relative position doubles as the view direction because the camera is at the origin.
		float sideX = velocityY * pz - velocityZ * py;
		float sideY = velocityZ * px - velocityX * pz;
		float sideZ = velocityX * py - velocityY * px;
		float sideLength = (float) Math.sqrt(sideX * sideX + sideY * sideY + sideZ * sideZ);
		if (sideLength < 1e-5f) {
			return;
		}
		float scale = half / sideLength;
		sideX *= scale;
		sideY *= scale;
		sideZ *= scale;
		float tail = Math.min(0.6f, speed * 0.06f) / speed;
		float tx = px - velocityX * tail;
		float ty = py - velocityY * tail;
		float tz = pz - velocityZ * tail;
		int faded = ColorUtil.withAlpha(color, 0);
		consumer.addVertex(pose, px + sideX, py + sideY, pz + sideZ).setColor(color);
		consumer.addVertex(pose, px - sideX, py - sideY, pz - sideZ).setColor(color);
		consumer.addVertex(pose, tx - sideX, ty - sideY, tz - sideZ).setColor(faded);
		consumer.addVertex(pose, tx + sideX, ty + sideY, tz + sideZ).setColor(faded);
	}

	private static void billboard(VertexConsumer consumer, PoseStack.Pose pose, float cx, float cy, float cz,
		Vector3fc up, Vector3fc left, float half, boolean diamond, int color) {
		float ux = up.x() * half;
		float uy = up.y() * half;
		float uz = up.z() * half;
		float lx = left.x() * half;
		float ly = left.y() * half;
		float lz = left.z() * half;
		if (diamond) {
			consumer.addVertex(pose, cx + ux, cy + uy, cz + uz).setColor(color);
			consumer.addVertex(pose, cx + lx, cy + ly, cz + lz).setColor(color);
			consumer.addVertex(pose, cx - ux, cy - uy, cz - uz).setColor(color);
			consumer.addVertex(pose, cx - lx, cy - ly, cz - lz).setColor(color);
		} else {
			consumer.addVertex(pose, cx + ux + lx, cy + uy + ly, cz + uz + lz).setColor(color);
			consumer.addVertex(pose, cx - ux + lx, cy - uy + ly, cz - uz + lz).setColor(color);
			consumer.addVertex(pose, cx - ux - lx, cy - uy - ly, cz - uz - lz).setColor(color);
			consumer.addVertex(pose, cx + ux - lx, cy + uy - ly, cz + uz - lz).setColor(color);
		}
	}
}
