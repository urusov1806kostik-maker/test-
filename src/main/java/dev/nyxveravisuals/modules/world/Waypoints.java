package dev.nyxveravisuals.modules.world;

import java.util.List;

import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.world.phys.Vec3;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.event.events.HudRenderEvent;
import dev.nyxveravisuals.event.events.WorldRenderEvent;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.WorldProjection;
import dev.nyxveravisuals.render.WorldRenderer3D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.util.ColorUtil;
import dev.nyxveravisuals.util.MathUtil;
import dev.nyxveravisuals.waypoint.Waypoint;

/**
 * Shows the waypoints of the current world and dimension (managed on the Config page) as screen-space labels
 * with distance, plus an optional light beam. Labels never scale with distance, so far points stay readable.
 */
public final class Waypoints extends Module {
	private final NyxveraClient client;
	private final BooleanSetting showDistance = settings().add(new BooleanSetting("show_distance", true));
	private final BooleanSetting beams = settings().add(new BooleanSetting("beams", true));
	private final BooleanSetting deathPoints = settings().add(new BooleanSetting("show_death_points", true));
	private final NumberSetting maxDistance = settings().add(new NumberSetting("max_distance", 5000, 50, 30000, 50).suffix("m"));
	private final NumberSetting scale = settings().add(new NumberSetting("scale", 1.0, 0.5, 2.0, 0.05).suffix("x"));
	private final WorldProjection.ScreenPoint point = new WorldProjection.ScreenPoint();

	public Waypoints(NyxveraClient client) {
		super("waypoints", Category.WORLD);
		this.client = client;
		on(HudRenderEvent.class, this::render2d);
		on(WorldRenderEvent.class, this::render3d);
	}

	private List<Waypoint> current() {
		if (!client.session().inWorld()) {
			return List.of();
		}
		return client.waypoints().visibleIn(client.session().worldKey(), client.session().dimension());
	}

	private boolean shown(Waypoint waypoint, LocalPlayer player) {
		if (waypoint.kind() == Waypoint.Kind.DEATH && !deathPoints.get()) {
			return false;
		}
		double max = maxDistance.getDouble();
		return waypoint.distanceTo(player.getX(), player.getY(), player.getZ()) <= max;
	}

	private void render3d(WorldRenderEvent event) {
		LocalPlayer player = Minecraft.getInstance().player;
		if (!beams.get() || player == null) {
			return;
		}
		WorldRenderer3D.Frame frame = event.frame();
		Vec3 camera = frame.camera();
		for (Waypoint waypoint : current()) {
			if (!shown(waypoint, player)) {
				continue;
			}
			double dx = waypoint.x() + 0.5 - camera.x;
			double dz = waypoint.z() + 0.5 - camera.z;
			// Beams are only useful at a distance; up close they would cut through the view.
			double horizontal = Math.sqrt(dx * dx + dz * dz);
			if (horizontal < 4) {
				continue;
			}
			float fade = (float) MathUtil.clamp((horizontal - 4) / 12.0, 0, 1);
			int color = waypoint.color();
			float x = (float) dx;
			float z = (float) dz;
			float bottom = (float) (waypoint.y() - camera.y);
			float top = bottom + 256f;
			// Rendered far beams are pulled into the view range so they are not clipped by the far plane.
			float range = Minecraft.getInstance().options.getEffectiveRenderDistance() * 16f - 8f;
			if (horizontal > range) {
				float pull = (float) (range / horizontal);
				x *= pull;
				z *= pull;
			}
			var pose = frame.poses().last();
			WorldRenderer3D.line(frame.lines(false), pose, x, bottom, z, x, top, z,
				ColorUtil.withAlpha(color, Math.round(170 * fade)), 2.5f);
		}
	}

	private void render2d(HudRenderEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
		LocalPlayer player = minecraft.player;
		if (player == null || !client.projection().isValid()) {
			return;
		}
		Renderer2D renderer = event.renderer();
		var theme = client.theme();
		float size = DesignTokens.FONT_SMALL;
		for (Waypoint waypoint : current()) {
			if (!shown(waypoint, player)) {
				continue;
			}
			if (!client.projection().project(waypoint.x() + 0.5, waypoint.y() + 1.2, waypoint.z() + 0.5, point)) {
				continue;
			}
			if (point.x < -80 || point.x > event.width() + 80 || point.y < -40 || point.y > event.height() + 40) {
				continue;
			}
			double distance = waypoint.distanceTo(player.getX(), player.getY(), player.getZ());
			String name = waypoint.name();
			String meters = showDistance.get() ? Math.round(distance) + "m" : null;
			float nameWidth = renderer.textWidth(name, size, FontManager.Weight.SEMIBOLD);
			float metersWidth = meters == null ? 0 : renderer.textWidth(meters, DesignTokens.FONT_CAPTION) + 6;
			float iconSize = 8;
			float width = iconSize + 4 + nameWidth + metersWidth + 12;
			float height = renderer.lineHeight(size) + 5;
			// Labels near the crosshair are faded so they do not cover what the player aims at.
			float centerDistance = (float) Math.hypot(point.x - event.width() / 2f, point.y - event.height() / 2f);
			float alpha = MathUtil.clamp(centerDistance / 40f, 0.35f, 1f);
			renderer.push();
			renderer.translate(point.x, point.y);
			renderer.scale(scale.getFloat());
			renderer.pushAlpha(alpha);
			float left = -width / 2f;
			float top = -height / 2f;
			renderer.rounded(left, top, width, height, DesignTokens.RADIUS_S, ColorUtil.withAlpha(theme.panel(), 205));
			renderer.rounded(left, top, 2, height, 1, waypoint.color());
			Icon icon = waypoint.kind() == Waypoint.Kind.DEATH ? Icon.CLOSE : Icon.PIN;
			icon.draw(renderer, left + 6, -iconSize / 2f, iconSize, waypoint.color());
			float textY = -renderer.fonts().visualCenter(size);
			renderer.text(name, left + 6 + iconSize + 4, textY, size, theme.textPrimary(), FontManager.Weight.SEMIBOLD, false);
			if (meters != null) {
				renderer.text(meters, left + 6 + iconSize + 4 + nameWidth + 6, -renderer.fonts().visualCenter(DesignTokens.FONT_CAPTION),
					DesignTokens.FONT_CAPTION, theme.textSecondary());
			}
			renderer.popAlpha();
			renderer.pop();
		}
	}
}
