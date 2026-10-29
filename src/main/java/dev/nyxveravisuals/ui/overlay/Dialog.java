package dev.nyxveravisuals.ui.overlay;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;
import java.util.function.Predicate;

import org.lwjgl.glfw.GLFW;

import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Button;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.component.TextField;

/**
 * Modal dialog: confirmation (optionally destructive) or a single-line text prompt. Dims the screen and
 * blocks all input beneath it; Enter confirms, Escape cancels.
 */
public final class Dialog extends Overlay {
	private static final float WIDTH = 210;

	private final String titleKey;
	private final String message;
	private final TextField input;
	private final Button confirm;
	private final Button cancel;
	private final List<Component> children = new ArrayList<>();
	private final Runnable confirmAction;
	private List<String> lines;

	private Dialog(UiContext context, String titleKey, String message, String confirmKey, boolean danger,
		TextField input, Runnable confirmAction) {
		super(true);
		this.titleKey = titleKey;
		this.message = message;
		this.input = input;
		this.confirmAction = confirmAction;
		this.confirm = new Button(confirmKey, danger ? Icon.TRASH : Icon.CHECK, danger ? Button.Style.DANGER : Button.Style.PRIMARY, this::accept);
		this.cancel = new Button("ui.cancel", null, Button.Style.SECONDARY, this::close);
		if (input != null) {
			children.add(input);
			context.focus(input);
		}
		children.add(cancel);
		children.add(confirm);
	}

	/** Asks for confirmation; {@code onConfirm} runs only if the user agrees. */
	public static void confirm(UiContext context, String titleKey, String message, boolean danger, Runnable onConfirm) {
		context.overlays().open(new Dialog(context, titleKey, message, danger ? "ui.delete" : "ui.confirm", danger, null, onConfirm));
	}

	public static void confirm(UiContext context, String titleKey, String message, String confirmKey, boolean danger, Runnable onConfirm) {
		context.overlays().open(new Dialog(context, titleKey, message, confirmKey, danger, null, onConfirm));
	}

	/** Asks for a value; {@code onSubmit} receives it only if {@code validator} accepts it. */
	public static void prompt(UiContext context, String titleKey, String initial, int maxLength, Predicate<String> validator, Consumer<String> onSubmit) {
		TextField field = new TextField(maxLength);
		field.setText(initial);
		Dialog[] holder = new Dialog[1];
		holder[0] = new Dialog(context, titleKey, null, "ui.confirm", false, field, () -> {
			if (validator.test(field.text())) {
				onSubmit.accept(field.text());
			}
		});
		field.onSubmit(value -> holder[0].accept());
		context.overlays().open(holder[0]);
	}

	private void accept() {
		close();
		confirmAction.run();
	}

	@Override
	protected void layout(UiContext context) {
		float size = context.text(DesignTokens.FONT_SMALL);
		float padding = DesignTokens.SPACE_L;
		if (lines == null) {
			lines = message == null ? List.of() : context.renderer().wrap(message, size, WIDTH - padding * 2);
		}
		float lineHeight = context.renderer().lineHeight(size);
		float height = padding + 14 + lines.size() * lineHeight + (input != null ? 24 : 0) + 8 + 18 + padding;
		float left = (context.width() - WIDTH) / 2f;
		float top = (context.height() - height) / 2f;
		setBounds(left, top, WIDTH, height);
		float cursor = top + padding + 14 + lines.size() * lineHeight;
		if (input != null) {
			input.setBounds(left + padding, cursor + 2, WIDTH - padding * 2, 18);
			cursor += 24;
		}
		float buttonWidth = (WIDTH - padding * 2 - 6) / 2f;
		cancel.setBounds(left + padding, top + height - padding - 18, buttonWidth, 18);
		confirm.setBounds(left + padding + buttonWidth + 6, top + height - padding - 18, buttonWidth, 18);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float appear = presence();
		renderer.pushAlpha(appear);
		renderer.rect(0, 0, context.width(), context.height(), 0x66000000);
		renderer.push();
		renderer.scaleAround(0.96f + 0.04f * appear, x + width / 2f, y + height / 2f);
		renderer.surface(x, y, width, height, DesignTokens.RADIUS_L, theme.panel(), theme.border(), theme.shadow(), 18);
		float padding = DesignTokens.SPACE_L;
		renderer.text(context.tr(titleKey), x + padding, y + padding - 1, context.text(DesignTokens.FONT_TITLE), theme.textPrimary(),
			FontManager.Weight.SEMIBOLD, false);
		float size = context.text(DesignTokens.FONT_SMALL);
		float lineHeight = renderer.lineHeight(size);
		float cursor = y + padding + 15;
		for (String line : lines) {
			renderer.text(line, x + padding, cursor, size, theme.textSecondary());
			cursor += lineHeight;
		}
		for (Component child : children) {
			child.render(context, mouseX, mouseY);
		}
		renderer.pop();
		renderer.popAlpha();
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		for (Component child : children) {
			if (child.mouseClicked(context, mouseX, mouseY, button)) {
				return true;
			}
		}
		return true;
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		return input != null && input.mouseDragged(context, mouseX, mouseY, button);
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		if (key == GLFW.GLFW_KEY_ESCAPE) {
			context.clearFocus();
			close();
			return true;
		}
		if (key == GLFW.GLFW_KEY_ENTER || key == GLFW.GLFW_KEY_KP_ENTER) {
			context.clearFocus();
			accept();
			return true;
		}
		if (input != null) {
			context.focus(input);
			return input.keyPressed(context, key, scancode, modifiers);
		}
		return true;
	}

	@Override
	public boolean charTyped(UiContext context, int codePoint) {
		return input != null && input.charTyped(context, codePoint);
	}
}
