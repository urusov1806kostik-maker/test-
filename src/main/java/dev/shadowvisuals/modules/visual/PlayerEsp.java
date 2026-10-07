package dev.shadowvisuals.modules.visual;

import net.minecraft.client.Minecraft;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.phys.AABB;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.event.events.HudRenderEvent;
import dev.shadowvisuals.event.events.WorldRenderEvent;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.WorldRenderer3D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.setting.MultiSelectSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Visual player highlighting: 2D frames, 3D boxes, vanilla-style glow outline and health bars. Players are
 * skipped early by distance and off-screen projection, so far or hidden players cost almost nothing.
 */
public final class PlayerEsp extends Module {
	public enum Look {
		BOX_2D,
		BOX_3D,
		OUTLINE,
		HEALTH_BAR
	}

	private final ShadowClient client;
	private final MultiSelectSetting<Look> looks = settings().add(new MultiSelectSetting<>("looks", Look.class, Look.BOX_2D, Look.HEALTH_BAR));
	private final NumberSetting maxDistance = settings().add(new NumberSetting("max_distance", 96, 8, 256, 4).suffix("m"));
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFF8B7CF6, true));
	private final ColorSetting friendColor = settings().add(new ColorSetting("friend_color", 0xFF3DD68C, true));
	private final BooleanSetting friends = settings().add(new BooleanSetting("show_friends", true));
	private final BooleanSetting invisible = settings().add(new BooleanSetting("show_invisible", false));
	private final BooleanSetting throughWalls = settings().add(new BooleanSetting("through_walls", true));
	private final float[] bounds = new float[4];

	public PlayerEsp(ShadowClient client) {
		super("player_esp", Category.VISUAL);
		this.client = client;
		on(WorldRenderEvent.class, this::render3d);
		on(HudRenderEvent.class, this::render2d);
	}

	/** Shared filter, also used by the glow-outline mixin. */
	public boolean targets(Entity entity) {
		Minecraft minecraft = Minecraft.getInstance();
		if (!(entity instanceof Player player) || player == minecraft.player || !player.isAlive()) {
			return false;
		}
		if (player.isInvisible() && !invisible.get()) {
			return false;
		}
		if (!friends.get() && client.friends().isFriend(player.getGameProfile().name())) {
			return false;
		}
		return minecraft.player != null && minecraft.player.distanceToSqr(player) <= maxDistance.getDouble() * maxDistance.getDouble();
	}

	public boolean outline() {
		return looks.contains(Look.OUTLINE);
	}

	public int colorFor(Entity entity) {
		return entity instanceof Player player && client.friends().isFriend(player.getGameProfile().name()) ? friendColor.color() : color.color();
	}

	private void render3d(WorldRenderEvent event) {
		if (!looks.contains(Look.BOX_3D)) {
			return;
		}
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.level == null) {
			return;
		}
		WorldRenderer3D.Frame frame = event.frame();
		float partial = frame.partialTick();
		for (Player player : minecraft.level.players()) {
			if (!targets(player)) {
				continue;
			}
			AABB box = interpolatedBox(player, partial);
			int argb = colorFor(player);
			WorldRenderer3D.boxFilled(frame, box, ColorUtil.withAlpha(argb, 38), throughWalls.get());
			WorldRenderer3D.boxOutline(frame, box, argb, 2f, throughWalls.get());
		}
	}

	static AABB interpolatedBox(Entity entity, float partial) {
		double x = Mth.lerp(partial, entity.xo, entity.getX()) - entity.getX();
		double y = Mth.lerp(partial, entity.yo, entity.getY()) - entity.getY();
		double z = Mth.lerp(partial, entity.zo, entity.getZ()) - entity.getZ();
		return entity.getBoundingBox().move(x, y, z);
	}

	private void render2d(HudRenderEvent event) {
		boolean box = looks.contains(Look.BOX_2D);
		boolean health = looks.contains(Look.HEALTH_BAR);
		Minecraft minecraft = Minecraft.getInstance();
		if (!box && !health || minecraft.level == null || !client.projection().isValid()) {
			return;
		}
		Renderer2D renderer = event.renderer();
		for (Player player : minecraft.level.players()) {
			if (!targets(player)) {
				continue;
			}
			AABB aabb = interpolatedBox(player, event.partialTick());
			if (!client.projection().projectBox(aabb.minX, aabb.minY, aabb.minZ, aabb.maxX, aabb.maxY, aabb.maxZ, bounds)) {
				continue;
			}
			float left = bounds[0];
			float top = bounds[1];
			float width = bounds[2] - bounds[0];
			float height = bounds[3] - bounds[1];
			if (bounds[2] < 0 || bounds[0] > event.width() || bounds[3] < 0 || bounds[1] > event.height() || width < 1) {
				continue;
			}
			int argb = colorFor(player);
			if (box) {
				renderer.outline(left - 1, top - 1, width + 2, height + 2, 1.5f, 1.5f, 0x99000000);
				renderer.outline(left, top, width, height, 1f, 1f, argb);
			}
			if (health) {
				float fraction = Mth.clamp(player.getHealth() / Math.max(1f, player.getMaxHealth()), 0f, 1f);
				float barX = left - 4;
				renderer.rounded(barX - 0.5f, top - 0.5f, 2.5f, height + 1, 1f, 0xAA000000);
				int healthColor = ColorUtil.lerp(client.theme().error(), client.theme().success(), fraction);
				renderer.rounded(barX, top + height * (1 - fraction), 1.5f, height * fraction, 0.75f, healthColor);
			}
		}
	}
}
