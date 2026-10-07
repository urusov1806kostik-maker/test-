package dev.shadowvisuals.modules.hud;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.ui.KeyNames;
import dev.shadowvisuals.util.ColorUtil;

/** Bound modules with their key and state. Resizes with its content; rows animate in and out. */
public final class KeybindsHud extends PanelHudModule {
	private static final class Row {
		final Animation presence = new Animation(0f, DesignTokens.DURATION_PANEL, Easing.EASE_OUT_CUBIC);
		final Animation state = new Animation(0f, DesignTokens.DURATION_TOGGLE, Easing.EASE_OUT_QUAD);
	}

	private final ShadowClient client;
	private final BooleanSetting onlyEnabled = settings().add(new BooleanSetting("only_enabled", false));
	private final Map<Module, Row> rows = new HashMap<>();
	private final List<Module> visible = new ArrayList<>();
	private final SmoothValue height = new SmoothValue(0f, 16f);

	public KeybindsHud(ShadowClient client) {
		super("keybinds", Category.HUD, false, HudAnchor.MIDDLE_LEFT, 4, 0);
		this.client = client;
	}

	private boolean shown(Module module) {
		return module.bind().get().isBound() && (!onlyEnabled.get() || module.isEnabled());
	}

	@Override
	protected boolean hasContent(HudContext context) {
		for (Module module : client.modules().all()) {
			if (shown(module)) {
				return true;
			}
		}
		return false;
	}

	@Override
	protected void renderContent(HudContext context) {
		Renderer2D renderer = context.renderer();
		visible.clear();
		for (Module module : client.modules().all()) {
			Row row = rows.get(module);
			boolean show = shown(module);
			if (show && row == null) {
				row = new Row();
				rows.put(module, row);
			}
			if (row != null) {
				row.presence.animateTo(show ? 1f : 0f);
				row.state.animateTo(module.isEnabled() ? 1f : 0f);
				if (show || !row.presence.isFinishedAtZero()) {
					visible.add(module);
				}
			}
		}
		rows.keySet().removeIf(module -> !shown(module) && rows.get(module).presence.isFinishedAtZero());

		float rowHeight = renderer.lineHeight(TEXT) + 3;
		float header = rowHeight + 2;
		float contentWidth = boldWidth(context, context.tr("hud.label.keybinds")) + 18;
		for (Module module : visible) {
			float rowWidth = width(context, context.tr(module.nameKey())) + 14 + width(context, KeyNames.name(module.bind().get(), context.i18n())) + 12;
			contentWidth = Math.max(contentWidth, rowWidth);
		}
		float targetRows = 0;
		for (Module module : visible) {
			targetRows += rows.get(module).presence.value();
		}
		height.setTarget(header + targetRows * rowHeight + PADDING * 2 - 2);
		float panelHeight = Math.max(header + PADDING, height.get());
		float panelWidth = contentWidth + PADDING * 2 + 4;
		panel(context, panelWidth, panelHeight);
		Icon.KEYBOARD.draw(renderer, PADDING + 3, PADDING, 9, context.theme().accent());
		bold(context, context.tr("hud.label.keybinds"), PADDING + 15, PADDING + 4.5f - renderer.fonts().visualCenter(TEXT), context.theme().textPrimary());

		renderer.pushClip(0, 0, panelWidth, panelHeight);
		float y = PADDING + header;
		for (Module module : visible) {
			Row row = rows.get(module);
			float presence = row.presence.value();
			renderer.pushAlpha(presence);
			float centerY = y + rowHeight / 2f;
			int stateColor = ColorUtil.lerp(context.theme().textDisabled(), context.theme().success(), row.state.value());
			renderer.circle(PADDING + 5, centerY, 2, stateColor);
			renderer.text(context.tr(module.nameKey()), PADDING + 11, centerY - renderer.fonts().visualCenter(TEXT), TEXT,
				module.isEnabled() ? context.theme().textPrimary() : context.theme().textSecondary(), FontManager.Weight.MEDIUM, textShadow());
			String key = KeyNames.name(module.bind().get(), context.i18n());
			float keyWidth = width(context, key) + 6;
			float keyX = panelWidth - PADDING - keyWidth;
			renderer.rounded(keyX, centerY - rowHeight / 2f + 1, keyWidth, rowHeight - 2, DesignTokens.RADIUS_XS, ColorUtil.withAlpha(context.theme().textPrimary(), 18));
			renderer.text(key, keyX + 3, centerY - renderer.fonts().visualCenter(TEXT), TEXT, context.theme().textSecondary());
			renderer.popAlpha();
			y += rowHeight * presence;
		}
		renderer.popClip();
		setSize(panelWidth, panelHeight);
	}
}
