package dev.shadowvisuals.modules.player;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;
import java.util.UUID;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;

import net.minecraft.client.Minecraft;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.Vec3;

import dev.shadowvisuals.animation.AnimationClock;
import dev.shadowvisuals.event.events.ClientTickEvent;
import dev.shadowvisuals.event.events.WorldLeaveEvent;
import dev.shadowvisuals.event.events.WorldRenderEvent;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.WorldRenderer3D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Fading ribbon behind moving players. Each player keeps a fixed-size ring buffer of positions sampled per
 * tick; histories of players that left render distance are dropped, and the number of tracked players is
 * capped, so memory stays bounded however long the session runs.
 */
public final class Trails extends Module {
	private static final int POINTS = 64;
	private static final int MAX_PLAYERS = 24;

	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFF8B7CF6, true));
	private final NumberSetting length = settings().add(new NumberSetting("length", 1.5, 0.3, 3.0, 0.1).suffix("s"));
	private final NumberSetting height = settings().add(new NumberSetting("height", 0.15, 0.02, 1.8, 0.01).suffix("m"));
	private final BooleanSetting others = settings().add(new BooleanSetting("others", false));
	private final BooleanSetting firstPerson = settings().add(new BooleanSetting("first_person", false));

	private final Map<UUID, History> histories = new HashMap<>();

	public Trails() {
		super("trails", Category.PLAYER);
		on(ClientTickEvent.class, this::tick);
		on(WorldRenderEvent.class, this::render);
		on(WorldLeaveEvent.class, event -> histories.clear());
	}

	@Override
	protected void onDisable() {
		histories.clear();
	}

	/** Positions with timestamps in a ring buffer; {@code count} grows to {@link #POINTS} and stays there. */
	private static final class History {
		final double[] xs = new double[POINTS];
		final double[] ys = new double[POINTS];
		final double[] zs = new double[POINTS];
		final double[] times = new double[POINTS];
		int head;
		int count;
		boolean seen;

		void add(double x, double y, double z, double time) {
			if (count > 0) {
				int last = (head - 1 + POINTS) % POINTS;
				double dx = x - xs[last];
				double dy = y - ys[last];
				double dz = z - zs[last];
				if (dx * dx + dy * dy + dz * dz < 0.0025) {
					return;
				}
				if (dx * dx + dy * dy + dz * dz > 64) {
					// Teleport: start a new trail instead of drawing a ribbon across the world.
					count = 0;
				}
			}
			xs[head] = x;
			ys[head] = y;
			zs[head] = z;
			times[head] = time;
			head = (head + 1) % POINTS;
			count = Math.min(count + 1, POINTS);
		}

		/** Index of the {@code n}-th newest point (0 = newest). */
		int index(int n) {
			return (head - 1 - n + POINTS * 2) % POINTS;
		}
	}

	private boolean tracks(Player player, Minecraft minecraft) {
		return player == minecraft.player || others.get() && !player.isInvisible() && player.isAlive();
	}

	private void tick(ClientTickEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
		if (event.isPre() || minecraft.level == null) {
			return;
		}
		double now = AnimationClock.global().now();
		for (History history : histories.values()) {
			history.seen = false;
		}
		for (Player player : minecraft.level.players()) {
			if (!tracks(player, minecraft)) {
				continue;
			}
			History history = histories.get(player.getUUID());
			if (history == null) {
				if (histories.size() >= MAX_PLAYERS) {
					continue;
				}
				history = new History();
				histories.put(player.getUUID(), history);
			}
			history.seen = true;
			history.add(player.getX(), player.getY(), player.getZ(), now);
		}
		for (Iterator<History> iterator = histories.values().iterator(); iterator.hasNext();) {
			if (!iterator.next().seen) {
				iterator.remove();
			}
		}
	}

	private void render(WorldRenderEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.level == null || histories.isEmpty()) {
			return;
		}
		double now = AnimationClock.global().now();
		double life = length.getDouble();
		float ribbon = height.getFloat();
		boolean firstPersonView = minecraft.options.getCameraType().isFirstPerson();
		WorldRenderer3D.Frame frame = event.frame();
		Vec3 camera = frame.camera();
		VertexConsumer consumer = frame.quads(false);
		PoseStack.Pose pose = frame.poses().last();
		for (Player player : minecraft.level.players()) {
			History history = histories.get(player.getUUID());
			if (history == null || history.count == 0) {
				continue;
			}
			if (player == minecraft.player && firstPersonView && !firstPerson.get()) {
				continue;
			}
			float partial = frame.partialTick();
			// The newest segment starts at the interpolated player position so the ribbon never lags behind.
			double previousX = Mth.lerp(partial, player.xo, player.getX());
			double previousY = Mth.lerp(partial, player.yo, player.getY());
			double previousZ = Mth.lerp(partial, player.zo, player.getZ());
			float previousFade = 1f;
			for (int n = 0; n < history.count; n++) {
				int i = history.index(n);
				double age = now - history.times[i];
				if (age >= life) {
					break;
				}
				float fade = 1f - (float) (age / life);
				int base = color.color(n * 0.015f);
				int alpha = ColorUtil.alpha(base);
				int newer = ColorUtil.withAlpha(base, Math.round(alpha * previousFade * 0.75f));
				int older = ColorUtil.withAlpha(base, Math.round(alpha * fade * 0.75f));
				float ax = (float) (previousX - camera.x);
				float ay = (float) (previousY - camera.y);
				float az = (float) (previousZ - camera.z);
				float bx = (float) (history.xs[i] - camera.x);
				float by = (float) (history.ys[i] - camera.y);
				float bz = (float) (history.zs[i] - camera.z);
				consumer.addVertex(pose, ax, ay, az).setColor(newer);
				consumer.addVertex(pose, bx, by, bz).setColor(older);
				consumer.addVertex(pose, bx, by + ribbon * fade, bz).setColor(ColorUtil.withAlpha(older, 0));
				consumer.addVertex(pose, ax, ay + ribbon * previousFade, az).setColor(ColorUtil.withAlpha(newer, 0));
				previousX = history.xs[i];
				previousY = history.ys[i];
				previousZ = history.zs[i];
				previousFade = fade;
			}
		}
	}
}
