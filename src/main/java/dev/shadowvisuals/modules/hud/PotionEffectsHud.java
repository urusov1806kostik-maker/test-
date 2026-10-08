package dev.shadowvisuals.modules.hud;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Gui;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.effect.MobEffectUtil;

import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.util.ColorUtil;

/** Active status effects with icon, level and remaining time; expiring effects blink gently. */
public final class PotionEffectsHud extends PanelHudModule {
	private final BooleanSetting showLevel = settings().add(new BooleanSetting("show_level", true));
	private final BooleanSetting hideVanilla = settings().add(new BooleanSetting("hide_vanilla", true));
	private final List<MobEffectInstance> effects = new ArrayList<>();
	private final List<String> names = new ArrayList<>();
	private final List<String> times = new ArrayList<>();

	public PotionEffectsHud() {
		super("potion_effects", Category.HUD, false, HudAnchor.TOP_RIGHT, -4, 60);
	}

	/** Read by the vanilla status-effect HUD replacement to hide the default icons. */
	public boolean hidesVanilla() {
		return isEnabled() && hideVanilla.get();
	}

	@Override
	protected boolean hasContent(HudContext context) {
		var player = Minecraft.getInstance().player;
		return player != null && !player.getActiveEffects().isEmpty();
	}

	@Override
	protected void renderContent(HudContext context) {
		Minecraft minecraft = Minecraft.getInstance();
		Renderer2D renderer = context.renderer();
		effects.clear();
		if (minecraft.player != null) {
			effects.addAll(minecraft.player.getActiveEffects());
		}
		effects.sort(Comparator.comparingInt(MobEffectInstance::getDuration).reversed());
		float rowHeight = 14;
		float width = 70;
		names.clear();
		times.clear();
		float tickRate = minecraft.level != null ? minecraft.level.tickRateManager().tickrate() : 20f;
		for (MobEffectInstance effect : effects) {
			String name = effect.getEffect().value().getDisplayName().getString();
			if (showLevel.get() && effect.getAmplifier() > 0) {
				name += " " + roman(effect.getAmplifier() + 1);
			}
			String time = MobEffectUtil.formatDuration(effect, 1f, tickRate).getString();
			names.add(name);
			times.add(time);
			width = Math.max(width, 12 + 4 + width(context, name) + 8 + width(context, time));
		}
		width += PADDING * 2 + 2;
		float height = Math.max(rowHeight, effects.size() * rowHeight) + PADDING * 2 - 2;
		panel(context, width, height);
		float y = PADDING - 1;
		double now = dev.shadowvisuals.animation.AnimationClock.global().now();
		for (int i = 0; i < effects.size(); i++) {
			MobEffectInstance effect = effects.get(i);
			boolean expiring = !effect.isInfiniteDuration() && effect.endsWithin(200);
			float blink = expiring ? (float) (0.55 + 0.45 * Math.cos(now * Math.PI * 2)) : 1f;
			renderer.pushAlpha(blink);
			renderer.sprite(Gui.getMobEffectSprite(effect.getEffect()), PADDING + 2, y + 1, 12);
			float centerY = y + rowHeight / 2f;
			int nameColor = effect.getEffect().value().isBeneficial() ? context.theme().textPrimary() : ColorUtil.lerp(context.theme().textPrimary(), context.theme().error(), 0.45f);
			text(context, names.get(i), PADDING + 18, centerY - renderer.fonts().visualCenter(TEXT), nameColor);
			String time = times.get(i);
			text(context, time, width - PADDING - width(context, time), centerY - renderer.fonts().visualCenter(TEXT),
				expiring ? context.theme().warning() : context.theme().textSecondary());
			renderer.popAlpha();
			y += rowHeight;
		}
		if (effects.isEmpty() && context.editing()) {
			text(context, context.tr("hud.label.potion_effects"), PADDING + 2, height / 2f - renderer.fonts().visualCenter(TEXT), context.theme().textSecondary());
		}
		setSize(width, height);
	}

	private static String roman(int value) {
		return switch (value) {
			case 1 -> "I";
			case 2 -> "II";
			case 3 -> "III";
			case 4 -> "IV";
			case 5 -> "V";
			case 6 -> "VI";
			case 7 -> "VII";
			case 8 -> "VIII";
			case 9 -> "IX";
			case 10 -> "X";
			default -> Integer.toString(value);
		};
	}
}
