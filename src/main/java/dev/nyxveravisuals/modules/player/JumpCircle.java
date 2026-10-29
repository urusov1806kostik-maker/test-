package dev.nyxveravisuals.modules.player;

import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;

import dev.nyxveravisuals.animation.AnimationClock;
import dev.nyxveravisuals.animation.Easing;
import dev.nyxveravisuals.event.events.ClientTickEvent;
import dev.nyxveravisuals.event.events.WorldLeaveEvent;
import dev.nyxveravisuals.event.events.WorldRenderEvent;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.WorldRenderer3D;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * Expanding, fading ground ring where the player jumps (and optionally lands). Circles live in a small
 * fixed ring buffer and age by wall-clock time, so the effect looks the same at any FPS and never grows.
 */
public final class JumpCircle extends Module {
	public enum Style {
		RING,
		SOFT,
		WAVE
	}

	private static final int CAPACITY = 16;
	private static final int SEGMENTS = 48;

	private final ModeSetting<Style> style = settings().add(new ModeSetting<>("style", Style.RING));
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFF8B7CF6, true));
	private final NumberSetting radius = settings().add(new NumberSetting("radius", 1.2, 0.4, 3.0, 0.1).suffix("m"));
	private final NumberSetting duration = settings().add(new NumberSetting("duration", 0.8, 0.2, 2.0, 0.05).suffix("s"));
	private final BooleanSetting onLanding = settings().add(new BooleanSetting("on_landing", false));

	private final double[] xs = new double[CAPACITY];
	private final double[] ys = new double[CAPACITY];
	private final double[] zs = new double[CAPACITY];
	private final double[] born = new double[CAPACITY];
	private int next;
	private boolean wasOnGround = true;

	public JumpCircle() {
		super("jump_circle", Category.PLAYER);
		java.util.Arrays.fill(born, Double.NEGATIVE_INFINITY);
		on(ClientTickEvent.class, this::tick);
		on(WorldRenderEvent.class, this::render);
		on(WorldLeaveEvent.class, event -> clear());
	}

	@Override
	protected void onDisable() {
		clear();
	}

	private void clear() {
		java.util.Arrays.fill(born, Double.NEGATIVE_INFINITY);
		wasOnGround = true;
	}

	private void tick(ClientTickEvent event) {
		LocalPlayer player = Minecraft.getInstance().player;
		if (event.isPre() || player == null) {
			return;
		}
		boolean onGround = player.onGround();
		if (wasOnGround && !onGround && player.getDeltaMovement().y > 0.1 && !player.isPassenger()) {
			spawn(player.getX(), player.getY(), player.getZ());
		} else if (!wasOnGround && onGround && onLanding.get()) {
			spawn(player.getX(), player.getY(), player.getZ());
		}
		wasOnGround = onGround;
	}

	private void spawn(double x, double y, double z) {
		xs[next] = x;
		ys[next] = Math.floor(y * 16) / 16 + 0.02;
		zs[next] = z;
		born[next] = AnimationClock.global().now();
		next = (next + 1) % CAPACITY;
	}

	private void render(WorldRenderEvent event) {
		double now = AnimationClock.global().now();
		double life = duration.getDouble();
		float maxRadius = radius.getFloat();
		for (int i = 0; i < CAPACITY; i++) {
			double age = now - born[i];
			if (age < 0 || age >= life) {
				continue;
			}
			float t = (float) (age / life);
			int base = color.color(i * 0.07f);
			switch (style.get()) {
				case RING -> ring(event, i, t, maxRadius, base);
				case SOFT -> soft(event, i, t, maxRadius, base);
				case WAVE -> {
					ring(event, i, t, maxRadius, base);
					float second = (t - 0.25f) / 0.75f;
					if (second > 0f) {
						ring(event, i, second, maxRadius * 0.7f, base);
					}
				}
			}
		}
	}

	/** Thin bright edge with a soft glow fading towards the center. */
	private void ring(WorldRenderEvent event, int i, float t, float maxRadius, int base) {
		float r = maxRadius * Easing.EASE_OUT_CUBIC.apply(t);
		int alpha = Math.round(ColorUtil.alpha(base) * (1f - t * t));
		int edge = ColorUtil.withAlpha(base, alpha);
		int glow = ColorUtil.withAlpha(base, Math.round(alpha * 0.35f));
		int clear = ColorUtil.withAlpha(base, 0);
		WorldRenderer3D.ring(event.frame(), xs[i], ys[i], zs[i], r * 0.55f, r * 0.92f, clear, glow, SEGMENTS, false);
		WorldRenderer3D.ring(event.frame(), xs[i], ys[i], zs[i], r * 0.92f, r, edge, edge, SEGMENTS, false);
	}

	/** Filled disc, brightest at the rim, without a hard edge. */
	private void soft(WorldRenderEvent event, int i, float t, float maxRadius, int base) {
		float r = maxRadius * Easing.EASE_OUT_QUINT.apply(t);
		int alpha = Math.round(ColorUtil.alpha(base) * (1f - t));
		WorldRenderer3D.ring(event.frame(), xs[i], ys[i], zs[i], 0f, r * 0.8f, ColorUtil.withAlpha(base, Math.round(alpha * 0.1f)),
			ColorUtil.withAlpha(base, Math.round(alpha * 0.45f)), SEGMENTS, false);
		WorldRenderer3D.ring(event.frame(), xs[i], ys[i], zs[i], r * 0.8f, r, ColorUtil.withAlpha(base, Math.round(alpha * 0.45f)),
			ColorUtil.withAlpha(base, 0), SEGMENTS, false);
	}
}
