package dev.shadowvisuals.modules.hud;

import java.util.Locale;

import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.PlayerInfo;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.entity.player.PlayerSkin;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Information about the entity you fight or look at: head, name, health and absorption with smoothly
 * animated numbers and bars, distance, armor and ping. Uses only client-visible data and keeps showing the
 * last target while it fades out instead of vanishing instantly.
 */
public final class TargetHud extends PanelHudModule {
	public enum Look {
		MODERN,
		COMPACT
	}

	private final ShadowClient client;
	private final ModeSetting<Look> look = settings().add(new ModeSetting<>("look", Look.MODERN));
	private final BooleanSetting onLook = settings().add(new BooleanSetting("show_on_look", true));
	private final NumberSetting timeout = settings().add(new NumberSetting("timeout", 3.0, 0.5, 10.0, 0.5).suffix("s"));
	private final BooleanSetting playersOnly = settings().add(new BooleanSetting("players_only", false));
	private final SmoothValue health = new SmoothValue(0f, 9f);
	private final SmoothValue healthTrail = new SmoothValue(0f, 2.2f);
	private final SmoothValue absorption = new SmoothValue(0f, 9f);
	private LivingEntity current;
	private LivingEntity shown;
	private long lastLookMillis;

	public TargetHud(ShadowClient client) {
		super("target_hud", Category.HUD, false, HudAnchor.CENTER, 70, 30);
		this.client = client;
	}

	private LivingEntity findTarget(Minecraft minecraft) {
		long timeoutMillis = Math.round(timeout.getDouble() * 1000);
		LivingEntity attacked = client.combat().recentTarget(timeoutMillis);
		if (onLook.get()) {
			Entity looked = minecraft.crosshairPickEntity;
			if (looked instanceof LivingEntity living && living.isAlive() && valid(living)) {
				lastLookMillis = System.currentTimeMillis();
				current = living;
				return living;
			}
		}
		if (attacked != null && valid(attacked)) {
			return attacked;
		}
		if (current != null && current.isAlive() && !current.isRemoved() && System.currentTimeMillis() - lastLookMillis <= timeoutMillis) {
			return current;
		}
		return null;
	}

	private boolean valid(LivingEntity entity) {
		return !playersOnly.get() || entity instanceof Player;
	}

	@Override
	protected boolean hasContent(HudContext context) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.player == null) {
			return false;
		}
		LivingEntity target = findTarget(minecraft);
		if (target != null) {
			if (target != shown) {
				health.snap(target.getHealth());
				healthTrail.snap(target.getHealth());
				absorption.snap(target.getAbsorptionAmount());
			}
			shown = target;
		}
		return target != null;
	}

	@Override
	protected void onDisable() {
		shown = null;
		current = null;
	}

	@Override
	protected void renderContent(HudContext context) {
		Minecraft minecraft = Minecraft.getInstance();
		LivingEntity target = shown;
		if (target == null || minecraft.player == null) {
			if (context.editing()) {
				drawPreview(context);
			} else {
				setSize(120, 36);
			}
			return;
		}
		health.setTarget(target.getHealth());
		healthTrail.setTarget(target.getHealth());
		absorption.setTarget(target.getAbsorptionAmount());
		String name = context.privacy().hideName() && target == minecraft.player ? context.tr("ui.profile.hidden_name") : target.getName().getString();
		float distance = minecraft.player.distanceTo(target);
		int ping = -1;
		PlayerSkin skin = null;
		if (target instanceof AbstractClientPlayer player && minecraft.getConnection() != null) {
			PlayerInfo info = minecraft.getConnection().getPlayerInfo(player.getUUID());
			if (info != null) {
				ping = info.getLatency();
				skin = info.getSkin();
			}
		}
		draw(context, name, skin, target.getMaxHealth(), target.getArmorValue(), distance, ping, target.hurtTime);
	}

	private void drawPreview(HudContext context) {
		health.setTarget(14f);
		healthTrail.setTarget(14f);
		absorption.setTarget(4f);
		draw(context, "Steve", null, 20f, 12, 3.4f, 42, 0);
	}

	private void draw(HudContext context, String name, PlayerSkin skin, float maxHealth, int armor, float distance, int ping, int hurtTime) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		boolean compact = look.get() == Look.COMPACT;
		float width = compact ? 118 : 142;
		float height = compact ? 26 : 42;
		panel(context, width, height);
		float head = height - PADDING * 2;
		float headX = PADDING + 1;
		float headY = PADDING;
		if (skin != null) {
			renderer.face(skin, headX, headY, head);
		} else {
			renderer.rounded(headX, headY, head, head, 4, theme.accentMuted(70));
			renderer.textMiddle(name.isEmpty() ? "?" : name.substring(0, 1).toUpperCase(Locale.ROOT), headX + head / 2f, headY + head / 2f, head * 0.45f,
				theme.textPrimary(), FontManager.Weight.SEMIBOLD, Renderer2D.Align.CENTER);
		}
		if (hurtTime > 0) {
			renderer.rounded(headX, headY, head, head, 3, ColorUtil.withAlpha(theme.error(), Math.round(110 * hurtTime / 10f)));
		}
		float textX = headX + head + 6;
		float textWidth = width - textX - PADDING - 2;
		float currentHealth = Math.max(0, health.get());
		float trail = Math.max(currentHealth, healthTrail.get());
		float absorb = Math.max(0, absorption.get());
		String healthText = String.format(Locale.ROOT, "%.1f", currentHealth + absorb);
		bold(context, renderer.ellipsize(name, TEXT, FontManager.Weight.SEMIBOLD, textWidth - boldWidth(context, healthText) - 6), textX, headY - 1, theme.textPrimary());
		float healthWidth = boldWidth(context, healthText);
		int healthColor = ColorUtil.lerp(theme.error(), theme.success(), Math.min(1f, currentHealth / Math.max(1f, maxHealth)));
		bold(context, healthText, width - PADDING - 2 - healthWidth, headY - 1, healthColor);

		float barY = compact ? headY + head - 4 : headY + 12;
		float barHeight = compact ? 3 : 4;
		float max = Math.max(1f, maxHealth);
		renderer.rounded(textX, barY, textWidth, barHeight, barHeight / 2f, ColorUtil.withAlpha(theme.textPrimary(), 22));
		renderer.rounded(textX, barY, textWidth * Math.min(1f, trail / max), barHeight, barHeight / 2f, ColorUtil.withAlpha(theme.error(), 120));
		renderer.gradientHorizontal(textX, barY, textWidth * Math.min(1f, currentHealth / max), barHeight, barHeight / 2f,
			ColorUtil.shade(healthColor, -0.1f), healthColor);
		if (absorb > 0.05f) {
			renderer.rounded(textX, barY + barHeight + 1, textWidth * Math.min(1f, absorb / max), 1.6f, 0.8f, theme.warning());
		}
		if (compact) {
			setSize(width, height);
			return;
		}
		float chipsY = barY + barHeight + 5;
		float cursor = textX;
		cursor = chip(context, Icon.MOVE, String.format(Locale.ROOT, "%.1fm", distance), cursor, chipsY);
		cursor = chip(context, Icon.LAYOUT, Integer.toString(armor), cursor, chipsY);
		if (ping >= 0) {
			chip(context, Icon.GLOBE, ping + "ms", cursor, chipsY);
		}
		setSize(width, height);
	}

	private float chip(HudContext context, Icon icon, String value, float x, float y) {
		Renderer2D renderer = context.renderer();
		float size = DesignTokens.FONT_CAPTION;
		float width = 7 + 3 + renderer.textWidth(value, size) + 6;
		renderer.rounded(x, y, width, 10, 3, ColorUtil.withAlpha(context.theme().textPrimary(), 14));
		icon.draw(renderer, x + 3, y + 1.5f, 7, context.theme().textSecondary());
		renderer.text(value, x + 12, y + 5 - renderer.fonts().visualCenter(size), size, context.theme().textSecondary());
		return x + width + 3;
	}
}
