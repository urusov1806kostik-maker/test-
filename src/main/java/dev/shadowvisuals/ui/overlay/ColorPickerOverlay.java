package dev.shadowvisuals.ui.overlay;

import java.util.List;

import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.ui.component.Button;
import dev.shadowvisuals.ui.component.Component;
import dev.shadowvisuals.ui.component.Slider;
import dev.shadowvisuals.ui.component.TextField;
import dev.shadowvisuals.ui.component.Toggle;
import dev.shadowvisuals.util.ColorUtil;
import dev.shadowvisuals.util.MathUtil;

/**
 * HSV color picker with alpha, hex input, optional rainbow and reset. Edits apply live to the setting.
 * Placed next to its anchor and clamped to the screen; as an overlay it has input priority.
 */
public final class ColorPickerOverlay extends Overlay {
	private static final float PADDING = 8;
	private static final float SQUARE_HEIGHT = 84;
	private static final float BAR = 9;
	private static final float PANEL_WIDTH = 158;

	private enum Drag {
		NONE,
		SATURATION_VALUE,
		HUE,
		ALPHA
	}

	private static final int[] HUE_STOPS = {0xFFFF0000, 0xFFFFFF00, 0xFF00FF00, 0xFF00FFFF, 0xFF0000FF, 0xFFFF00FF, 0xFFFF0000};

	private final Component anchor;
	private final ColorSetting setting;
	private final int original;
	private final float[] hsv = new float[3];
	private float alpha;
	private Drag drag = Drag.NONE;

	private final TextField hex;
	private final Toggle rainbow;
	private final Slider rainbowSpeed;
	private final Button reset;
	private final List<Component> children;

	public ColorPickerOverlay(Component anchor, ColorSetting setting) {
		super(false);
		this.anchor = anchor;
		this.setting = setting;
		this.original = setting.argb();
		syncFromSetting();
		this.hex = new TextField(9).filter(text -> text.matches("#?[0-9a-fA-F]{0,8}")).onChange(this::applyHex);
		this.hex.setText(ColorUtil.toHex(setting.argb(), setting.allowAlpha()));
		this.rainbow = new Toggle(setting::isRainbow, value -> setting.set(setting.get().withRainbow(value)));
		this.rainbowSpeed = new Slider(new Slider.Model() {
			@Override
			public double progress() {
				return (setting.get().rainbowSpeed() - ColorSetting.MIN_RAINBOW_SPEED) / (ColorSetting.MAX_RAINBOW_SPEED - ColorSetting.MIN_RAINBOW_SPEED);
			}

			@Override
			public void setProgress(double progress) {
				float speed = (float) (ColorSetting.MIN_RAINBOW_SPEED + progress * (ColorSetting.MAX_RAINBOW_SPEED - ColorSetting.MIN_RAINBOW_SPEED));
				setting.set(setting.get().withRainbowSpeed(Math.round(speed * 2f) / 2f));
			}

			@Override
			public void step(int steps) {
				setting.set(setting.get().withRainbowSpeed(setting.get().rainbowSpeed() + steps * 0.5f));
			}
		});
		this.reset = new Button("ui.reset", Icon.RESET, Button.Style.SECONDARY, () -> {
			setting.reset();
			syncFromSetting();
			hex.setText(ColorUtil.toHex(setting.argb(), setting.allowAlpha()));
		});
		this.children = List.of(hex, rainbow, rainbowSpeed, reset);
	}

	private void syncFromSetting() {
		int argb = setting.argb();
		ColorUtil.toHsv(argb, hsv);
		alpha = ColorUtil.alpha(argb) / 255f;
	}

	private void applyHsv() {
		int argb = ColorUtil.fromHsv(hsv[0], hsv[1], hsv[2], Math.round(alpha * 255));
		setting.setArgb(argb);
		hex.setText(ColorUtil.toHex(setting.argb(), setting.allowAlpha()));
	}

	private void applyHex(String text) {
		Integer parsed = ColorUtil.parseHex(text);
		if (parsed != null && (text.replace("#", "").length() == 6 || text.replace("#", "").length() == 8)) {
			setting.setArgb(parsed);
			syncFromSetting();
		}
	}

	private float contentHeight() {
		float height = PADDING + SQUARE_HEIGHT + 6;
		if (setting.allowAlpha()) {
			height += BAR + 6;
		}
		height += 16 + 6; // preview + hex
		height += 14 + 4; // rainbow
		if (setting.isRainbow()) {
			height += 12;
		}
		height += 16 + PADDING; // reset
		return height;
	}

	@Override
	protected void layout(UiContext context) {
		float height = contentHeight();
		float left = anchor.x() + anchor.width() + 6;
		if (left + PANEL_WIDTH > context.width() - 4) {
			left = anchor.x() - PANEL_WIDTH - 6;
		}
		left = MathUtil.clamp(left, 4, context.width() - PANEL_WIDTH - 4);
		float top = MathUtil.clamp(anchor.y() - 10, 4, context.height() - height - 4);
		setBounds(left, top, PANEL_WIDTH, height);

		float inner = PANEL_WIDTH - PADDING * 2;
		float cursor = top + PADDING + SQUARE_HEIGHT + 6;
		if (setting.allowAlpha()) {
			cursor += BAR + 6;
		}
		hex.setBounds(left + PADDING + 34, cursor, inner - 34, 16);
		cursor += 22;
		rainbow.setBounds(left + PANEL_WIDTH - PADDING - rainbow.width(), cursor + 1.5f, rainbow.width(), rainbow.height());
		cursor += 18;
		if (setting.isRainbow()) {
			rainbowSpeed.setBounds(left + PADDING, cursor - 1, inner, 10);
			cursor += 12;
		} else {
			rainbowSpeed.setBounds(-1000, -1000, 0, 0);
		}
		reset.setBounds(left + PADDING, cursor, inner, 16);
	}

	private float squareWidth() {
		return PANEL_WIDTH - PADDING * 3 - BAR;
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		if (drag == Drag.NONE && !context.isFocused(hex)) {
			int current = setting.argb();
			if (current != ColorUtil.fromHsv(hsv[0], hsv[1], hsv[2], Math.round(alpha * 255))) {
				syncFromSetting();
			}
		}
		renderer.pushAlpha(presence());
		renderer.surface(x, y, width, height, DesignTokens.RADIUS_L, ColorUtil.shade(theme.panel(), 0.02f), theme.border(), theme.shadow(), 14);

		float squareX = x + PADDING;
		float squareY = y + PADDING;
		float squareWidth = squareWidth();
		int hueColor = ColorUtil.fromHsv(hsv[0], 1, 1, 255);
		renderer.gradientHorizontal(squareX, squareY, squareWidth, SQUARE_HEIGHT, DesignTokens.RADIUS_S, 0xFFFFFFFF, hueColor);
		renderer.gradientVertical(squareX, squareY, squareWidth, SQUARE_HEIGHT, DesignTokens.RADIUS_S, 0x00000000, 0xFF000000);
		float markerX = squareX + hsv[1] * squareWidth;
		float markerY = squareY + (1 - hsv[2]) * SQUARE_HEIGHT;
		renderer.ring(markerX, markerY, 3.5f, 1.4f, 0xFFFFFFFF);
		renderer.ring(markerX, markerY, 4.6f, 0.8f, 0x66000000);

		float hueX = squareX + squareWidth + PADDING;
		float segment = SQUARE_HEIGHT / (HUE_STOPS.length - 1);
		for (int i = 0; i < HUE_STOPS.length - 1; i++) {
			renderer.gradientVertical(hueX, squareY + i * segment, BAR, segment + 0.5f, 0, HUE_STOPS[i], HUE_STOPS[i + 1]);
		}
		renderer.outline(hueX, squareY, BAR, SQUARE_HEIGHT, 2, 1, theme.border());
		float hueMarker = squareY + hsv[0] * SQUARE_HEIGHT;
		renderer.rounded(hueX - 1.5f, hueMarker - 1.5f, BAR + 3, 3, 1.5f, 0xFFFFFFFF);

		float cursor = squareY + SQUARE_HEIGHT + 6;
		if (setting.allowAlpha()) {
			drawChecker(renderer, squareX, cursor, PANEL_WIDTH - PADDING * 2, BAR);
			int opaque = setting.argb() | 0xFF000000;
			renderer.gradientHorizontal(squareX, cursor, PANEL_WIDTH - PADDING * 2, BAR, 2, opaque & 0x00FFFFFF, opaque);
			renderer.outline(squareX, cursor, PANEL_WIDTH - PADDING * 2, BAR, 2, 1, theme.border());
			float alphaMarker = squareX + alpha * (PANEL_WIDTH - PADDING * 2);
			renderer.rounded(alphaMarker - 1.5f, cursor - 1.5f, 3, BAR + 3, 1.5f, 0xFFFFFFFF);
			cursor += BAR + 6;
		}

		drawChecker(renderer, squareX, cursor, 28, 16);
		renderer.rounded(squareX, cursor, 14, 16, 0, original);
		renderer.rounded(squareX + 14, cursor, 14, 16, 0, setting.color());
		renderer.outline(squareX, cursor, 28, 16, DesignTokens.RADIUS_S, 1, theme.border());

		float size = context.text(DesignTokens.FONT_SMALL);
		float rainbowY = rainbow.y() + rainbow.height() / 2f;
		renderer.textMiddle(context.tr("ui.color.rainbow"), squareX, rainbowY, size, theme.textPrimary(), FontManager.Weight.MEDIUM, Renderer2D.Align.LEFT);
		for (Component child : children) {
			child.render(context, mouseX, mouseY);
		}
		renderer.popAlpha();
	}

	private static void drawChecker(Renderer2D renderer, float x, float y, float width, float height) {
		float cell = 4;
		renderer.rect(x, y, width, height, 0xFFDADADA);
		for (int row = 0; row * cell < height; row++) {
			for (int column = row % 2; column * cell < width; column += 2) {
				float cellWidth = Math.min(cell, width - column * cell);
				float cellHeight = Math.min(cell, height - row * cell);
				renderer.rect(x + column * cell, y + row * cell, cellWidth, cellHeight, 0xFFA8A8A8);
			}
		}
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		for (Component child : children) {
			if (child.mouseClicked(context, mouseX, mouseY, button)) {
				return true;
			}
		}
		float squareX = x + PADDING;
		float squareY = y + PADDING;
		float squareWidth = squareWidth();
		if (mouseY >= squareY && mouseY <= squareY + SQUARE_HEIGHT) {
			if (mouseX >= squareX && mouseX <= squareX + squareWidth) {
				drag = Drag.SATURATION_VALUE;
			} else if (mouseX >= squareX + squareWidth + PADDING - 2 && mouseX <= squareX + squareWidth + PADDING + BAR + 2) {
				drag = Drag.HUE;
			}
		} else if (setting.allowAlpha() && mouseY >= squareY + SQUARE_HEIGHT + 4 && mouseY <= squareY + SQUARE_HEIGHT + 6 + BAR + 2) {
			drag = Drag.ALPHA;
		}
		if (drag != Drag.NONE) {
			context.clearFocus();
			updateDrag(mouseX, mouseY);
		}
		return true;
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		if (drag != Drag.NONE) {
			updateDrag(mouseX, mouseY);
			return true;
		}
		for (Component child : children) {
			if (child.mouseDragged(context, mouseX, mouseY, button)) {
				return true;
			}
		}
		return false;
	}

	@Override
	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		drag = Drag.NONE;
		for (Component child : children) {
			child.mouseReleased(context, mouseX, mouseY, button);
		}
		return true;
	}

	private void updateDrag(float mouseX, float mouseY) {
		float squareX = x + PADDING;
		float squareY = y + PADDING;
		switch (drag) {
			case SATURATION_VALUE -> {
				hsv[1] = MathUtil.clamp((mouseX - squareX) / squareWidth(), 0f, 1f);
				hsv[2] = 1f - MathUtil.clamp((mouseY - squareY) / SQUARE_HEIGHT, 0f, 1f);
			}
			case HUE -> hsv[0] = MathUtil.clamp((mouseY - squareY) / SQUARE_HEIGHT, 0f, 0.999f);
			case ALPHA -> alpha = MathUtil.clamp((mouseX - squareX) / (PANEL_WIDTH - PADDING * 2), 0f, 1f);
			default -> {
				return;
			}
		}
		applyHsv();
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		if (context.isFocused(hex)) {
			if (key == org.lwjgl.glfw.GLFW.GLFW_KEY_ESCAPE || key == org.lwjgl.glfw.GLFW.GLFW_KEY_ENTER) {
				context.clearFocus();
				return true;
			}
			return hex.keyPressed(context, key, scancode, modifiers);
		}
		return super.keyPressed(context, key, scancode, modifiers);
	}

	@Override
	public boolean charTyped(UiContext context, int codePoint) {
		return hex.charTyped(context, codePoint);
	}
}
