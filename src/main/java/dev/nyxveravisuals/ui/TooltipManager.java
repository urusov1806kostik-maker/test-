package dev.nyxveravisuals.ui;

import java.util.List;

import dev.nyxveravisuals.animation.AnimationClock;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.util.ColorUtil;
import dev.nyxveravisuals.util.MathUtil;

/**
 * Delayed tooltips anchored to the hovered component (not the cursor), so they never jitter. Components
 * offer a tooltip while hovered; it appears once the same source stays hovered for the delay.
 */
public final class TooltipManager {
	private Object source;
	private Object previousSource;
	private String text;
	private float anchorX;
	private float anchorY;
	private float anchorWidth;
	private float anchorHeight;
	private double hoverStart;
	private String wrappedFor;
	private List<String> lines = List.of();

	public void beginFrame() {
		previousSource = source;
		source = null;
	}

	public void offer(Object owner, String tooltip, float x, float y, float width, float height) {
		if (owner != previousSource) {
			hoverStart = AnimationClock.global().now();
		}
		this.source = owner;
		this.text = tooltip;
		this.anchorX = x;
		this.anchorY = y;
		this.anchorWidth = width;
		this.anchorHeight = height;
	}

	public void reset() {
		source = null;
		previousSource = null;
	}

	public void render(UiContext context) {
		if (source == null || text == null || text.isEmpty()) {
			return;
		}
		float delay = AnimationClock.global().mode() == AnimationClock.Mode.OFF ? 0.25f : DesignTokens.TOOLTIP_DELAY;
		float shown = (float) (AnimationClock.global().now() - hoverStart) - delay;
		if (shown <= 0) {
			return;
		}
		float alpha = AnimationClock.global().mode() == AnimationClock.Mode.OFF ? 1f : MathUtil.clamp(shown / 0.12f, 0f, 1f);
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float size = context.text(DesignTokens.FONT_SMALL);
		float padding = DesignTokens.SPACE_S;
		if (!text.equals(wrappedFor)) {
			lines = renderer.wrap(text, size, DesignTokens.TOOLTIP_MAX_WIDTH);
			wrappedFor = text;
		}
		float textWidth = 0;
		for (String line : lines) {
			textWidth = Math.max(textWidth, renderer.textWidth(line, size));
		}
		float lineHeight = renderer.lineHeight(size);
		float boxWidth = textWidth + padding * 2;
		float boxHeight = lines.size() * lineHeight + padding * 2 - (lineHeight - size);
		float x = MathUtil.clamp(anchorX, 4, context.width() - boxWidth - 4);
		float y = anchorY + anchorHeight + 4;
		if (y + boxHeight > context.height() - 4) {
			y = anchorY - boxHeight - 4;
		}
		y = MathUtil.clamp(y, 4, context.height() - boxHeight - 4);
		renderer.pushAlpha(alpha);
		renderer.surface(x, y, boxWidth, boxHeight, DesignTokens.RADIUS_M,
			ColorUtil.shade(theme.panel(), 0.03f), theme.border(), theme.shadow(), 10);
		float lineY = y + padding - 1;
		for (String line : lines) {
			renderer.text(line, x + padding, lineY, size, theme.textPrimary());
			lineY += lineHeight;
		}
		renderer.popAlpha();
	}
}
