package dev.nyxveravisuals.ui.clickgui;

import java.util.ArrayList;
import java.util.List;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.animation.Animation;
import dev.nyxveravisuals.animation.Easing;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Button;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.component.ScrollPanel;
import dev.nyxveravisuals.ui.overlay.Dialog;
import dev.nyxveravisuals.ui.settings.SectionLabel;
import dev.nyxveravisuals.ui.settings.SettingRow;
import dev.nyxveravisuals.ui.settings.SettingsList;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * Slide-in settings panel for one module, layered above the module grid. It reuses the shared setting
 * rows, so every module gets the same controls, reset buttons and tooltips.
 */
public final class ModuleSettingsPanel extends Component {
	private final NyxveraClient client;
	private final Animation slide = new Animation(0f, DesignTokens.DURATION_PANEL, Easing.EASE_OUT_CUBIC);
	private final ScrollPanel list = new ScrollPanel(ScrollPanel.stack(2)).padding(2);
	private final Button close = Button.icon(Icon.CLOSE, "ui.close", this::close);
	private final Button reset;
	private Module module;
	private List<String> descriptionLines = List.of();
	private float describedWidth = -1;
	private UiContext lastContext;

	public ModuleSettingsPanel(NyxveraClient client) {
		this.client = client;
		this.reset = Button.icon(Icon.RESET, "ui.module.reset", this::confirmReset);
	}

	public void open(UiContext context, Module target) {
		this.lastContext = context;
		this.module = target;
		this.describedWidth = -1;
		List<Component> rows = new ArrayList<>(SettingsList.build(context, target.settings(), node -> !target.isCoreSetting(node)));
		rows.add(new SectionLabel("ui.section.binding"));
		rows.add(new SettingRow(context, target.bind(), () -> true, 0));
		rows.add(new SettingRow(context, target.bindMode(), () -> target.bind().get().isBound(), 0));
		rows.add(new SettingRow(context, target.hiddenFromList(), () -> true, 0));
		list.setChildren(rows);
		list.resetScroll();
		slide.animateTo(1f);
	}

	private void confirmReset() {
		if (module != null && lastContext != null) {
			Module target = module;
			Dialog.confirm(lastContext, "ui.module.reset", lastContext.tr("ui.module.reset_confirm", lastContext.tr(target.nameKey())), "ui.reset", true,
				target::resetSettings);
		}
	}

	public void close() {
		slide.animateTo(0f);
		if (lastContext != null) {
			lastContext.clearFocus();
		}
	}

	public boolean isOpen() {
		return module != null && slide.target() > 0f;
	}

	/** True while visible, including the closing slide. */
	public boolean isShowing() {
		return module != null && slide.value() > 0.001f;
	}

	public Module module() {
		return module;
	}

	@Override
	public boolean contains(float pointX, float pointY) {
		return isShowing() && super.contains(pointX, pointY);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		if (!isShowing()) {
			return;
		}
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float progress = slide.value();
		float offset = (1 - progress) * (width + 12);
		renderer.pushAlpha(Math.min(1f, progress * 1.4f));
		renderer.push();
		renderer.translate(offset, 0);
		float left = x;
		renderer.shadow(left, y, width, height, DesignTokens.RADIUS_L, 16, ColorUtil.withAlpha(0, 120));
		renderer.rounded(left, y, width, height, DesignTokens.RADIUS_L, ColorUtil.shade(theme.panel(), 0.015f));
		renderer.outline(left, y, width, height, DesignTokens.RADIUS_L, 1, theme.border());

		float padding = DesignTokens.SPACE_L;
		float titleSize = context.text(DesignTokens.FONT_TITLE);
		close.setBounds(left + width - padding - 14, y + padding - 3, 14, 14);
		reset.setBounds(left + width - padding - 32, y + padding - 3, 14, 14);
		String title = renderer.ellipsize(context.tr(module.nameKey()), titleSize, FontManager.Weight.SEMIBOLD, width - padding * 2 - 40);
		renderer.text(title, left + padding, y + padding - 1, titleSize, theme.textPrimary(), FontManager.Weight.SEMIBOLD, false);

		float descriptionSize = context.text(DesignTokens.FONT_CAPTION);
		float textWidth = width - padding * 2;
		if (describedWidth != textWidth) {
			descriptionLines = renderer.wrap(context.tr(module.descriptionKey()), descriptionSize, textWidth);
			describedWidth = textWidth;
		}
		float cursor = y + padding + titleSize + 4;
		for (String line : descriptionLines) {
			renderer.text(line, left + padding, cursor, descriptionSize, theme.textSecondary());
			cursor += descriptionSize * 1.3f;
		}
		cursor += 4;
		renderer.rect(left + padding, cursor, width - padding * 2, 1, theme.border());
		cursor += 5;
		float mx = mouseX - offset;
		list.setBounds(left + padding - 2, cursor, width - padding * 2 + 4, y + height - cursor - padding + 4);
		list.render(context, mx, mouseY);
		close.render(context, mx, mouseY);
		reset.render(context, mx, mouseY);
		renderer.pop();
		renderer.popAlpha();
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (!isOpen()) {
			return false;
		}
		if (!super.contains(mouseX, mouseY)) {
			close();
			return true;
		}
		if (close.mouseClicked(context, mouseX, mouseY, button) || reset.mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		list.mouseClicked(context, mouseX, mouseY, button);
		return true;
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		return isOpen() && list.mouseDragged(context, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		return list.mouseReleased(context, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseScrolled(UiContext context, float mouseX, float mouseY, double amount) {
		if (!isOpen() || !super.contains(mouseX, mouseY)) {
			return false;
		}
		list.mouseScrolled(context, mouseX, mouseY, amount);
		return true;
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		return isOpen() && list.keyPressed(context, key, scancode, modifiers);
	}
}
