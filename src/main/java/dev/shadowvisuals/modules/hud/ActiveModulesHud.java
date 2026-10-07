package dev.shadowvisuals.modules.hud;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.HudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Enabled-module list. Entries slide and fade in/out, the list re-sorts smoothly and aligns to the side of
 * the screen it is anchored to. Defaults are restrained: theme text, a thin accent bar, soft background.
 */
public final class ActiveModulesHud extends HudModule {
	public enum Sorting {
		LENGTH,
		ALPHABETICAL
	}

	public enum TextColor {
		THEME,
		ACCENT,
		GRADIENT,
		RAINBOW
	}

	public enum Bar {
		NONE,
		SIDE,
		OUTLINE
	}

	private static final class Entry {
		final Module module;
		final Animation presence = new Animation(0f, DesignTokens.DURATION_PANEL, Easing.EASE_OUT_CUBIC);
		final SmoothValue slot = new SmoothValue(-1f, 14f);
		String text = "";

		Entry(Module module) {
			this.module = module;
		}
	}

	private final ShadowClient client;
	private final ModeSetting<Sorting> sorting = settings().add(new ModeSetting<>("sorting", Sorting.LENGTH));
	private final ModeSetting<TextColor> textColor = settings().add(new ModeSetting<>("text_color", TextColor.THEME));
	private final ModeSetting<Bar> bar = settings().add(new ModeSetting<>("bar", Bar.SIDE));
	private final BooleanSetting background = settings().add(new BooleanSetting("background", true));
	private final NumberSetting backgroundOpacity = settings().add(new NumberSetting("background_opacity", 0.55, 0.05, 1.0, 0.05)).dependsOn(background);
	private final BooleanSetting suffixes = settings().add(new BooleanSetting("suffixes", true));
	private final NumberSetting spacing = settings().add(new NumberSetting("spacing", 1, 0, 6, 0.5));
	private final BooleanSetting hideHud = settings().add(new BooleanSetting("hide_hud_modules", true));
	private final Map<Module, Entry> entries = new HashMap<>();
	private final List<Entry> ordered = new ArrayList<>();

	public ActiveModulesHud(ShadowClient client) {
		super("active_modules", Category.HUD, true, HudAnchor.TOP_RIGHT, -4, 4);
		this.client = client;
	}

	private boolean listed(Module module) {
		return module.isEnabled() && !module.hiddenFromList().get() && module != this && !(hideHud.get() && module instanceof HudModule);
	}

	private void update(HudContext context) {
		for (Module module : client.modules().all()) {
			boolean show = listed(module);
			Entry entry = entries.get(module);
			if (show && entry == null) {
				entry = new Entry(module);
				entries.put(module, entry);
			}
			if (entry != null) {
				entry.presence.animateTo(show ? 1f : 0f);
				String suffix = suffixes.get() ? module.listSuffix() : null;
				entry.text = context.tr(module.nameKey()) + (suffix == null ? "" : " " + suffix);
			}
		}
		entries.values().removeIf(entry -> entry.presence.isFinishedAtZero() && !listed(entry.module));
		ordered.clear();
		ordered.addAll(entries.values());
		Renderer2D renderer = context.renderer();
		Comparator<Entry> comparator = sorting.get() == Sorting.LENGTH
			? Comparator.comparingDouble((Entry entry) -> -renderer.textWidth(entry.text, DesignTokens.FONT_SMALL, FontManager.Weight.MEDIUM))
			: Comparator.comparing((Entry entry) -> entry.text.toLowerCase(java.util.Locale.ROOT));
		ordered.sort(comparator);
	}

	@Override
	protected boolean hasContent(HudContext context) {
		for (Module module : client.modules().all()) {
			if (listed(module)) {
				return true;
			}
		}
		return !entries.isEmpty();
	}

	@Override
	protected void renderContent(HudContext context) {
		update(context);
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		boolean right = anchor().alignsRight();
		float size = DesignTokens.FONT_SMALL;
		float rowHeight = renderer.lineHeight(size) + 3 + spacing.getFloat();
		float maxWidth = 0;
		for (Entry entry : ordered) {
			maxWidth = Math.max(maxWidth, renderer.textWidth(entry.text, size) + 10);
		}
		if (ordered.isEmpty() && context.editing()) {
			maxWidth = 60;
		}
		float slotIndex = 0;
		for (int i = 0; i < ordered.size(); i++) {
			Entry entry = ordered.get(i);
			float presence = entry.presence.value();
			if (entry.slot.target() < 0) {
				entry.slot.snap(slotIndex);
			}
			entry.slot.setTarget(slotIndex);
			float y = entry.slot.get() * rowHeight;
			float textWidth = renderer.textWidth(entry.text, size);
			float width = textWidth + 10;
			float slide = (1 - presence) * (width + 6) * (right ? 1 : -1);
			float x = (right ? maxWidth - width : 0) + slide;
			renderer.pushAlpha(presence);
			int color = color(theme, i);
			if (background.get()) {
				renderer.rounded(x, y, width, rowHeight - spacing.getFloat(), DesignTokens.RADIUS_XS,
					ColorUtil.withAlpha(theme.panel(), Math.round(255 * backgroundOpacity.getFloat())));
			}
			if (bar.get() == Bar.SIDE) {
				float barX = right ? x + width - 1.5f : x;
				renderer.rounded(barX, y + 1.5f, 1.5f, rowHeight - spacing.getFloat() - 3, 0.75f, color == theme.textPrimary() ? theme.accent() : color);
			} else if (bar.get() == Bar.OUTLINE) {
				renderer.outline(x, y, width, rowHeight - spacing.getFloat(), DesignTokens.RADIUS_XS, 1, ColorUtil.withAlpha(theme.accent(), 120));
			}
			renderer.text(entry.text, x + 5, y + (rowHeight - spacing.getFloat()) / 2f - renderer.fonts().visualCenter(size), size, color,
				FontManager.Weight.MEDIUM, !background.get());
			renderer.popAlpha();
			slotIndex += presence;
		}
		setSize(Math.max(20, maxWidth), Math.max(rowHeight, slotIndex * rowHeight));
	}

	private int color(ThemeManager theme, int index) {
		return switch (textColor.get()) {
			case ACCENT -> theme.accent();
			case GRADIENT -> ColorUtil.lerp(theme.accent(), theme.accentSecondary(), Math.min(1f, index / 8f));
			case RAINBOW -> ColorUtil.rainbow(dev.shadowvisuals.animation.AnimationClock.global().now(), 2f, index * 0.06f, 0.55f, 1f, 255);
			default -> theme.textPrimary();
		};
	}
}
