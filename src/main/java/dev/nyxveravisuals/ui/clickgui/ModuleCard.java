package dev.nyxveravisuals.ui.clickgui;

import java.util.List;
import java.util.function.Consumer;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.animation.Animation;
import dev.nyxveravisuals.animation.Easing;
import dev.nyxveravisuals.core.UiSounds;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.setting.SettingNode;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.KeyNames;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.component.Toggle;
import dev.nyxveravisuals.ui.overlay.ContextMenu;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * Module tile: name, short description, switch, favorite star, bind chip and settings affordance. Size is
 * fixed by the grid, hover only changes colors (no layout shift). Clicking the body opens settings.
 */
public final class ModuleCard extends Component {
	private final NyxveraClient client;
	private final Module module;
	private final Consumer<Module> openSettings;
	private final Animation switchAnimation;
	private final Animation enabledGlow;
	private String wrappedDescription;
	private float wrappedWidth = -1;
	private int wrappedRevision = -1;
	private List<String> descriptionLines = List.of();

	public ModuleCard(NyxveraClient client, Module module, Consumer<Module> openSettings) {
		this.client = client;
		this.module = module;
		this.openSettings = openSettings;
		this.switchAnimation = new Animation(module.isEnabled() ? 1f : 0f, DesignTokens.DURATION_TOGGLE, Easing.EASE_OUT_BACK);
		this.enabledGlow = new Animation(module.isEnabled() ? 1f : 0f, DesignTokens.DURATION_PANEL, Easing.EASE_OUT_QUAD);
	}

	public Module module() {
		return module;
	}

	private boolean hasSettings() {
		for (SettingNode node : module.settings().roots()) {
			if (!node.isInternal() && !module.isCoreSetting(node)) {
				return true;
			}
		}
		return false;
	}

	private float switchX() {
		return x + width - DesignTokens.TOGGLE_WIDTH - 10;
	}

	private float switchY() {
		return y + 9;
	}

	private float starX() {
		return switchX() - 15;
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		boolean enabled = module.isEnabled();
		switchAnimation.animateTo(enabled ? 1f : 0f);
		enabledGlow.animateTo(enabled ? 1f : 0f);
		float hover = hover();
		float glow = enabledGlow.value();

		int fill = ColorUtil.lerp(theme.card(), theme.cardHover(), hover);
		int border = ColorUtil.lerp(theme.border(), theme.accentMuted(110), Math.max(glow * 0.75f, hover * 0.35f));
		renderer.shadow(x, y + 1, width, height, DesignTokens.RADIUS_L, 8, ColorUtil.withAlpha(0, Math.round(40 + hover * 30)));
		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_L, fill);
		if (glow > 0.01f) {
			renderer.gradientHorizontal(x, y, width, height, DesignTokens.RADIUS_L,
				theme.accentMuted(Math.round(26 * glow)), ColorUtil.withAlpha(theme.accentSecondary(), 0));
		}
		renderer.outline(x, y, width, height, DesignTokens.RADIUS_L, 1, border);

		float textLeft = x + 10;
		float titleSize = context.text(DesignTokens.FONT_BODY);
		float rightReserved = width - (starX() - x) + 4;
		String name = renderer.ellipsize(context.tr(module.nameKey()), titleSize, FontManager.Weight.SEMIBOLD, width - 20 - rightReserved);
		renderer.text(name, textLeft, y + 8, titleSize, enabled ? theme.textPrimary() : ColorUtil.lerp(theme.textSecondary(), theme.textPrimary(), 0.75f),
			FontManager.Weight.SEMIBOLD, false);

		float descriptionSize = context.text(DesignTokens.FONT_CAPTION);
		float descriptionWidth = width - 20 - 40;
		String description = context.tr(module.descriptionKey());
		if (!description.equals(wrappedDescription) || wrappedWidth != descriptionWidth || wrappedRevision != context.i18n().revision()) {
			wrappedDescription = description;
			wrappedWidth = descriptionWidth;
			wrappedRevision = context.i18n().revision();
			List<String> lines = renderer.wrap(description, descriptionSize, descriptionWidth);
			if (lines.size() > 2) {
				lines = List.of(lines.get(0), renderer.ellipsize(lines.get(1) + " " + lines.get(2), descriptionSize, FontManager.Weight.MEDIUM, descriptionWidth));
			}
			descriptionLines = lines;
		}
		float lineY = y + 21;
		for (String line : descriptionLines) {
			renderer.text(line, textLeft, lineY, descriptionSize, theme.textSecondary());
			lineY += descriptionSize * 1.3f;
		}

		boolean switchHovered = mouseX >= switchX() - 2 && mouseX <= switchX() + DesignTokens.TOGGLE_WIDTH + 2 && mouseY >= switchY() - 2
			&& mouseY <= switchY() + DesignTokens.TOGGLE_HEIGHT + 2;
		if (module.isToggleable()) {
			Toggle.drawSwitch(context, switchX(), switchY(), DesignTokens.TOGGLE_WIDTH, DesignTokens.TOGGLE_HEIGHT, switchAnimation.value(), switchHovered ? 1f : 0f);
		}

		boolean favorite = client.modules().isFavorite(module);
		if (favorite || hover > 0.01f) {
			int starColor = favorite ? theme.warning() : ColorUtil.withAlpha(theme.textSecondary(), Math.round(200 * hover));
			(favorite ? Icon.STAR_FILLED : Icon.STAR).draw(renderer, starX(), switchY() + 0.5f, 10, starColor);
		}

		float bottom = y + height - 8;
		if (module.hasFailed()) {
			chip(context, x + width - 10, bottom, context.tr("ui.module.failed"), theme.error());
		} else if (module.bind().get().isBound()) {
			chip(context, x + width - 10, bottom, KeyNames.name(module.bind().get(), context.i18n()), theme.textSecondary());
		} else if (hasSettings() && hover > 0.01f) {
			Icon.GEAR.draw(renderer, x + width - 19, bottom - 9, 9, ColorUtil.withAlpha(theme.textSecondary(), Math.round(220 * hover)));
		}
	}

	private void chip(UiContext context, float right, float bottom, String text, int color) {
		Renderer2D renderer = context.renderer();
		float size = context.text(DesignTokens.FONT_CAPTION) * 0.92f;
		float chipWidth = renderer.textWidth(text, size, FontManager.Weight.SEMIBOLD) + 8;
		float chipHeight = 10;
		renderer.rounded(right - chipWidth, bottom - chipHeight, chipWidth, chipHeight, 3, ColorUtil.withAlpha(color, 30));
		renderer.textMiddle(text, right - chipWidth / 2f, bottom - chipHeight / 2f, size, color, FontManager.Weight.SEMIBOLD, Renderer2D.Align.CENTER);
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (!contains(mouseX, mouseY)) {
			return false;
		}
		if (button == 1) {
			openMenu(context, mouseX, mouseY);
			return true;
		}
		if (button == 2) {
			client.modules().toggleFavorite(module);
			return true;
		}
		if (button != 0) {
			return true;
		}
		boolean onSwitch = mouseX >= switchX() - 3 && mouseX <= switchX() + DesignTokens.TOGGLE_WIDTH + 3
			&& mouseY >= switchY() - 3 && mouseY <= switchY() + DesignTokens.TOGGLE_HEIGHT + 3;
		if (onSwitch && module.isToggleable()) {
			module.toggle();
			context.sounds().play(module.isEnabled() ? UiSounds.Kind.TOGGLE_ON : UiSounds.Kind.TOGGLE_OFF);
			return true;
		}
		boolean onStar = mouseX >= starX() - 2 && mouseX <= starX() + 12 && mouseY >= switchY() - 2 && mouseY <= switchY() + 12;
		if (onStar) {
			client.modules().toggleFavorite(module);
			context.sounds().play(UiSounds.Kind.CLICK);
			return true;
		}
		context.sounds().play(UiSounds.Kind.CLICK);
		openSettings.accept(module);
		return true;
	}

	private void openMenu(UiContext context, float mouseX, float mouseY) {
		boolean favorite = client.modules().isFavorite(module);
		ContextMenu.Builder menu = ContextMenu.at(mouseX, mouseY);
		if (module.isToggleable()) {
			menu.item(module.isEnabled() ? "ui.module.disable" : "ui.module.enable", Icon.CHECK, module::toggle);
		}
		menu.item("ui.module.settings", Icon.SLIDERS, () -> openSettings.accept(module))
			.item(favorite ? "ui.module.unfavorite" : "ui.module.favorite", favorite ? Icon.STAR_FILLED : Icon.STAR,
				() -> client.modules().toggleFavorite(module))
			.item(module.hiddenFromList().get() ? "ui.module.show_in_list" : "ui.module.hide_in_list", Icon.EYE_OFF,
				() -> module.hiddenFromList().toggle())
			.separator();
		if (module.bind().get().isBound()) {
			menu.item("ui.module.clear_bind", Icon.KEYBOARD, () -> module.bind().clear());
		}
		menu.danger("ui.module.reset", Icon.RESET, module::resetSettings).open(context);
	}
}
