package dev.shadowvisuals.ui.component;

import org.lwjgl.glfw.GLFW;

import dev.shadowvisuals.core.UiSounds;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.Keybind;
import dev.shadowvisuals.setting.KeybindSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.KeyNames;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Bind chip. Click to listen; the next key (or middle/side mouse button) assigns, Escape cancels,
 * Backspace/Delete removes the bind. While listening it holds keyboard focus.
 */
public final class KeybindSelector extends Component {
	private final KeybindSetting setting;

	public KeybindSelector(KeybindSetting setting) {
		this.setting = setting;
		setBounds(0, 0, 48, DesignTokens.CONTROL_HEIGHT);
	}

	public boolean isListening(UiContext context) {
		return context.isFocused(this);
	}

	public float preferredWidth(UiContext context) {
		String label = isListening(context) ? context.tr("ui.bind.listening") : KeyNames.name(setting.get(), context.i18n());
		return Math.max(34, context.renderer().textWidth(label, context.text(DesignTokens.FONT_CAPTION), FontManager.Weight.SEMIBOLD) + DesignTokens.SPACE_M * 2);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		boolean listening = isListening(context);
		boolean bound = setting.get().isBound();
		int fill = listening ? theme.accentMuted(60) : ColorUtil.shade(theme.background(), 0.03f + hover() * 0.03f);
		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_S, fill);
		renderer.outline(x, y, width, height, DesignTokens.RADIUS_S, 1, listening ? theme.accentMuted(180) : theme.border());
		String label = listening ? context.tr("ui.bind.listening") : KeyNames.name(setting.get(), context.i18n());
		float size = context.text(DesignTokens.FONT_CAPTION);
		int color = listening ? theme.textPrimary() : bound ? theme.textPrimary() : theme.textDisabled();
		renderer.textMiddle(renderer.ellipsize(label, size, FontManager.Weight.SEMIBOLD, width - 6), x + width / 2f, y + height / 2f,
			size, color, FontManager.Weight.SEMIBOLD, Renderer2D.Align.CENTER);
	}

	@Override
	protected String tooltip(UiContext context) {
		return context.tr("ui.bind.tooltip");
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (isListening(context)) {
			if (button >= 2) {
				setting.set(Keybind.mouse(button));
				context.clearFocus();
				context.sounds().play(UiSounds.Kind.CLICK);
				return true;
			}
			// A click while listening only cancels; it must not reach the widget under the cursor.
			context.clearFocus();
			return true;
		}
		if (!contains(mouseX, mouseY)) {
			return false;
		}
		if (button == 0) {
			context.focus(this);
			context.sounds().play(UiSounds.Kind.CLICK);
			return true;
		}
		if (button == 1) {
			setting.clear();
			return true;
		}
		return false;
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		if (!isListening(context)) {
			return false;
		}
		switch (key) {
			case GLFW.GLFW_KEY_ESCAPE -> context.clearFocus();
			case GLFW.GLFW_KEY_BACKSPACE, GLFW.GLFW_KEY_DELETE -> {
				setting.clear();
				context.clearFocus();
			}
			default -> {
				setting.set(Keybind.key(key));
				context.clearFocus();
			}
		}
		context.sounds().play(UiSounds.Kind.CLICK);
		return true;
	}

	@Override
	public boolean charTyped(UiContext context, int codePoint) {
		return isListening(context);
	}
}
