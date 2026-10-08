package dev.shadowvisuals.modules.hud;

import java.util.Locale;

import java.util.List;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Gui;
import net.minecraft.client.multiplayer.PlayerInfo;
import net.minecraft.client.player.AbstractClientPlayer;
import net.minecraft.core.Holder;
import net.minecraft.util.Mth;
import net.minecraft.world.effect.MobEffect;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.entity.player.PlayerSkin;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Items;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.core.VisibleEffects;
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
import dev.shadowvisuals.util.Numbers;

/**
 * Information about the entity you fight or look at: head, name, health and absorption with smoothly
 * animated numbers and bars, distance, armor and ping, plus what matters in PvP on servers like FunTime:
 * worn armor and held items with durability, totems popped and the effects the target visibly has. Uses only
 * client-visible data (effects are recognized from their particles, without levels or durations) and keeps
 * showing the last target while it fades out instead of vanishing instantly.
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
	private final BooleanSetting showEquipment = settings().add(new BooleanSetting("show_equipment", true));
	private final BooleanSetting showEffects = settings().add(new BooleanSetting("show_effects", true));
	private final BooleanSetting showPops = settings().add(new BooleanSetting("show_pops", true));
	private final BooleanSetting hitShake = settings().add(new BooleanSetting("hit_shake", true));
	private final SmoothValue health = new SmoothValue(0f, 9f);
	private final SmoothValue healthTrail = new SmoothValue(0f, 2.2f);
	private final SmoothValue absorption = new SmoothValue(0f, 9f);
	private static final EquipmentSlot[] EQUIPMENT = {EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET,
		EquipmentSlot.MAINHAND, EquipmentSlot.OFFHAND};
	private static final ItemStack TOTEM = new ItemStack(Items.TOTEM_OF_UNDYING);

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
		draw(context, target, name, skin, target.getMaxHealth(), target.getArmorValue(), distance, ping, target.hurtTime);
	}

	private void drawPreview(HudContext context) {
		health.setTarget(14f);
		healthTrail.setTarget(14f);
		absorption.setTarget(4f);
		// The editor preview uses your own gear so the extra rows can be positioned too.
		draw(context, Minecraft.getInstance().player, "Steve", null, 20f, 12, 3.4f, 42, 0);
	}

	private void draw(HudContext context, LivingEntity gear, String name, PlayerSkin skin, float maxHealth, int armor, float distance, int ping,
		int hurtTime) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		boolean compact = look.get() == Look.COMPACT;
		float width = compact ? 118 : 142;
		List<Holder<MobEffect>> effects = !compact && showEffects.get() && gear != null && !context.editing() ? VisibleEffects.of(gear) : List.of();
		boolean equipmentRow = !compact && showEquipment.get() && gear != null && hasEquipment(gear);
		float baseHeight = compact ? 26 : 42;
		float height = baseHeight + (equipmentRow ? 14 : 0) + (effects.isEmpty() ? 0 : 12);
		if (hitShake.get() && hurtTime > 0) {
			// A short decaying shake when the target takes a hit.
			float strength = hurtTime / 10f;
			renderer.translate(Mth.sin(hurtTime * 2.4f) * 1.6f * strength, 0);
		}
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
		String healthText = Numbers.fixed(currentHealth + absorb, 1);
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
		cursor = chip(context, Icon.MOVE, Numbers.fixed(distance, 1) + "m", cursor, chipsY);
		cursor = chip(context, Icon.LAYOUT, Integer.toString(armor), cursor, chipsY);
		if (ping >= 0) {
			cursor = chip(context, Icon.GLOBE, ping + "ms", cursor, chipsY);
		}
		int pops = showPops.get() && gear != null && !context.editing() ? client.combat().totemPops(gear) : 0;
		if (pops > 0) {
			popsChip(context, pops, cursor, chipsY);
		}
		float rowY = baseHeight - 1;
		if (equipmentRow) {
			float x = PADDING + 1;
			for (EquipmentSlot slot : EQUIPMENT) {
				ItemStack stack = gear.getItemBySlot(slot);
				if (slot == EquipmentSlot.MAINHAND) {
					x += 4;
				}
				if (!stack.isEmpty()) {
					renderer.itemWithOverlay(stack, x, rowY, 12);
				}
				x += 14;
			}
			rowY += 14;
		}
		if (!effects.isEmpty()) {
			float x = PADDING + 1;
			for (Holder<MobEffect> effect : effects) {
				if (x + 10 > width - PADDING) {
					break;
				}
				renderer.sprite(Gui.getMobEffectSprite(effect), x, rowY, 10);
				x += 12;
			}
		}
		setSize(width, height);
	}

	private static boolean hasEquipment(LivingEntity entity) {
		for (EquipmentSlot slot : EQUIPMENT) {
			if (!entity.getItemBySlot(slot).isEmpty()) {
				return true;
			}
		}
		return false;
	}

	private void popsChip(HudContext context, int pops, float x, float y) {
		Renderer2D renderer = context.renderer();
		float size = DesignTokens.FONT_CAPTION;
		String value = "×" + pops;
		float width = 9 + 2 + renderer.textWidth(value, size) + 5;
		renderer.rounded(x, y, width, 10, 3, ColorUtil.withAlpha(context.theme().warning(), 40));
		renderer.item(TOTEM, x + 2, y + 1, 8);
		renderer.text(value, x + 11, y + 5 - renderer.fonts().visualCenter(size), size, context.theme().warning());
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
