package dev.shadowvisuals.ui.component;

import java.util.function.Consumer;
import java.util.function.Predicate;

import org.lwjgl.glfw.GLFW;

import net.minecraft.client.Minecraft;

import dev.shadowvisuals.animation.AnimationClock;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Single-line text input with caret, selection, clipboard, word navigation and horizontal scrolling. While
 * focused it consumes all keys, so typing never triggers binds or GUI shortcuts.
 */
public final class TextField extends Component {
	private final int maxLength;
	private String text = "";
	private String placeholderKey;
	private Icon icon;
	private int caret;
	private int anchor;
	private float scroll;
	private double lastEdit;
	private Predicate<String> filter = value -> true;
	private Consumer<String> onChange = value -> { };
	private Consumer<String> onSubmit = value -> { };

	public TextField(int maxLength) {
		this.maxLength = maxLength;
		setBounds(0, 0, 100, DesignTokens.CONTROL_HEIGHT + 2);
	}

	public TextField placeholder(String key) {
		this.placeholderKey = key;
		return this;
	}

	public TextField icon(Icon value) {
		this.icon = value;
		return this;
	}

	public TextField filter(Predicate<String> predicate) {
		this.filter = predicate;
		return this;
	}

	public TextField onChange(Consumer<String> listener) {
		this.onChange = listener;
		return this;
	}

	public TextField onSubmit(Consumer<String> listener) {
		this.onSubmit = listener;
		return this;
	}

	public String text() {
		return text;
	}

	/** Replaces the content without firing the change listener (used to sync from the model). */
	public void setText(String value) {
		String clean = value == null ? "" : value;
		if (clean.length() > maxLength) {
			clean = clean.substring(0, maxLength);
		}
		text = clean;
		caret = Math.min(caret, text.length());
		anchor = caret;
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		boolean focused = context.isFocused(this);
		int fill = ColorUtil.shade(theme.background(), 0.02f + hover() * 0.02f);
		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_M, fill);
		renderer.outline(x, y, width, height, DesignTokens.RADIUS_M, 1, focused ? theme.accentMuted(170) : theme.border());

		float size = context.text(DesignTokens.FONT_SMALL);
		float padding = DesignTokens.SPACE_S;
		float left = x + padding;
		if (icon != null) {
			float iconSize = DesignTokens.ICON_SMALL;
			icon.draw(renderer, left, y + (height - iconSize) / 2f, iconSize, focused ? theme.textPrimary() : theme.textSecondary());
			left += iconSize + DesignTokens.SPACE_XS;
		}
		float visible = x + width - padding - left;
		float centerY = y + height / 2f;
		if (text.isEmpty() && !focused && placeholderKey != null) {
			renderer.textMiddle(renderer.ellipsize(context.tr(placeholderKey), size, dev.shadowvisuals.render.font.FontManager.Weight.MEDIUM, visible),
				left, centerY, size, theme.textDisabled());
			return;
		}
		float caretOffset = renderer.textWidth(text.substring(0, caret), size);
		if (caretOffset - scroll > visible) {
			scroll = caretOffset - visible;
		} else if (caretOffset - scroll < 0) {
			scroll = caretOffset;
		}
		scroll = Math.max(0, Math.min(scroll, Math.max(0, renderer.textWidth(text, size) - visible)));

		renderer.pushClip(left - 1, y, visible + 2, height);
		if (focused && caret != anchor) {
			float start = renderer.textWidth(text.substring(0, Math.min(caret, anchor)), size) - scroll;
			float end = renderer.textWidth(text.substring(0, Math.max(caret, anchor)), size) - scroll;
			renderer.rect(left + start, centerY - size * 0.62f, end - start, size * 1.24f, theme.accentMuted(90));
		}
		renderer.textMiddle(text, left - scroll, centerY, size, theme.textPrimary());
		if (focused) {
			double sinceEdit = AnimationClock.global().now() - lastEdit;
			boolean blinkOn = sinceEdit < 0.5 || ((long) (sinceEdit * 1.8)) % 2 == 0;
			if (blinkOn) {
				renderer.rect(left + caretOffset - scroll, centerY - size * 0.6f, 0.8f, size * 1.2f, theme.accent());
			}
		}
		renderer.popClip();
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (!contains(mouseX, mouseY)) {
			if (context.isFocused(this)) {
				context.clearFocus();
			}
			return false;
		}
		context.focus(this);
		if (button == 1) {
			setTextAndNotify("");
			return true;
		}
		caret = indexAt(context, mouseX);
		anchor = caret;
		lastEdit = AnimationClock.global().now();
		return true;
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		if (!context.isFocused(this) || button != 0) {
			return false;
		}
		caret = indexAt(context, mouseX);
		return true;
	}

	private int indexAt(UiContext context, float mouseX) {
		Renderer2D renderer = context.renderer();
		float size = context.text(DesignTokens.FONT_SMALL);
		float left = x + DesignTokens.SPACE_S + (icon != null ? DesignTokens.ICON_SMALL + DesignTokens.SPACE_XS : 0);
		float target = mouseX - left + scroll;
		for (int i = 0; i < text.length(); i++) {
			float mid = (renderer.textWidth(text.substring(0, i), size) + renderer.textWidth(text.substring(0, i + 1), size)) / 2f;
			if (target < mid) {
				return i;
			}
		}
		return text.length();
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		if (!context.isFocused(this)) {
			return false;
		}
		boolean shift = (modifiers & GLFW.GLFW_MOD_SHIFT) != 0;
		boolean control = (modifiers & (GLFW.GLFW_MOD_CONTROL | GLFW.GLFW_MOD_SUPER)) != 0;
		lastEdit = AnimationClock.global().now();
		switch (key) {
			case GLFW.GLFW_KEY_ESCAPE -> context.clearFocus();
			case GLFW.GLFW_KEY_ENTER, GLFW.GLFW_KEY_KP_ENTER -> onSubmit.accept(text);
			case GLFW.GLFW_KEY_BACKSPACE -> {
				if (!deleteSelection()) {
					int from = control ? wordBoundary(caret, -1) : Math.max(0, caret - 1);
					delete(from, caret);
				}
			}
			case GLFW.GLFW_KEY_DELETE -> {
				if (!deleteSelection()) {
					int to = control ? wordBoundary(caret, 1) : Math.min(text.length(), caret + 1);
					delete(caret, to);
				}
			}
			case GLFW.GLFW_KEY_LEFT -> moveCaret(control ? wordBoundary(caret, -1) : Math.max(0, caret - 1), shift);
			case GLFW.GLFW_KEY_RIGHT -> moveCaret(control ? wordBoundary(caret, 1) : Math.min(text.length(), caret + 1), shift);
			case GLFW.GLFW_KEY_HOME -> moveCaret(0, shift);
			case GLFW.GLFW_KEY_END -> moveCaret(text.length(), shift);
			case GLFW.GLFW_KEY_A -> {
				if (control) {
					anchor = 0;
					caret = text.length();
				}
			}
			case GLFW.GLFW_KEY_C -> {
				if (control && caret != anchor) {
					Minecraft.getInstance().keyboardHandler.setClipboard(selected());
				}
			}
			case GLFW.GLFW_KEY_X -> {
				if (control && caret != anchor) {
					Minecraft.getInstance().keyboardHandler.setClipboard(selected());
					deleteSelection();
				}
			}
			case GLFW.GLFW_KEY_V -> {
				if (control) {
					insert(Minecraft.getInstance().keyboardHandler.getClipboard());
				}
			}
			default -> {
				// Consume every other key so nothing leaks to binds or screen shortcuts while typing.
			}
		}
		return true;
	}

	@Override
	public boolean charTyped(UiContext context, int codePoint) {
		if (!context.isFocused(this)) {
			return false;
		}
		if (Character.isISOControl(codePoint) || codePoint == '§') {
			return true;
		}
		insert(Character.toString(codePoint));
		return true;
	}

	@Override
	public void onFocusLost(UiContext context) {
		anchor = caret;
	}

	private String selected() {
		return text.substring(Math.min(caret, anchor), Math.max(caret, anchor));
	}

	private void moveCaret(int position, boolean extendSelection) {
		caret = position;
		if (!extendSelection) {
			anchor = caret;
		}
	}

	private boolean deleteSelection() {
		if (caret == anchor) {
			return false;
		}
		delete(Math.min(caret, anchor), Math.max(caret, anchor));
		return true;
	}

	private void delete(int from, int to) {
		if (from >= to) {
			return;
		}
		String next = text.substring(0, from) + text.substring(to);
		if (filter.test(next)) {
			text = next;
			caret = from;
			anchor = caret;
			onChange.accept(text);
		}
	}

	private void insert(String value) {
		StringBuilder clean = new StringBuilder();
		value.codePoints().filter(cp -> !Character.isISOControl(cp) && cp != '§').forEach(clean::appendCodePoint);
		int from = Math.min(caret, anchor);
		int to = Math.max(caret, anchor);
		String inserted = clean.toString();
		int room = maxLength - (text.length() - (to - from));
		if (room <= 0) {
			return;
		}
		if (inserted.length() > room) {
			inserted = inserted.substring(0, room);
		}
		String next = text.substring(0, from) + inserted + text.substring(to);
		if (!filter.test(next)) {
			return;
		}
		text = next;
		caret = from + inserted.length();
		anchor = caret;
		onChange.accept(text);
	}

	private void setTextAndNotify(String value) {
		text = value;
		caret = text.length();
		anchor = caret;
		onChange.accept(text);
	}

	private int wordBoundary(int from, int direction) {
		int index = from;
		if (direction < 0) {
			while (index > 0 && text.charAt(index - 1) == ' ') {
				index--;
			}
			while (index > 0 && text.charAt(index - 1) != ' ') {
				index--;
			}
		} else {
			while (index < text.length() && text.charAt(index) != ' ') {
				index++;
			}
			while (index < text.length() && text.charAt(index) == ' ') {
				index++;
			}
		}
		return index;
	}
}
