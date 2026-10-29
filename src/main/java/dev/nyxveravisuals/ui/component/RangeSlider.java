package dev.nyxveravisuals.ui.component;

import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.setting.RangeSetting;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.util.ColorUtil;
import dev.nyxveravisuals.util.MathUtil;

/** Two-handle slider for a {@link RangeSetting}; the handle nearest to the cursor is dragged. */
public final class RangeSlider extends Component {
	private final RangeSetting setting;
	private int dragging = -1;

	public RangeSlider(RangeSetting setting) {
		this.setting = setting;
		setBounds(0, 0, 80, DesignTokens.SLIDER_KNOB + 2);
	}

	private float position(double value) {
		return x + (float) ((value - setting.min()) / (setting.max() - setting.min())) * width;
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float track = DesignTokens.SLIDER_TRACK;
		float trackY = y + (height - track) / 2f;
		renderer.rounded(x, trackY, width, track, track / 2f, ColorUtil.shade(theme.border(), 0.05f));
		float low = position(setting.low());
		float high = position(setting.high());
		renderer.gradientHorizontal(low, trackY, Math.max(track, high - low), track, track / 2f, theme.accent(), theme.accentSecondary());
		float knob = DesignTokens.SLIDER_KNOB * 0.9f;
		for (float handle : new float[] {low, high}) {
			renderer.shadow(handle - knob / 2f, y + height / 2f - knob / 2f + 0.5f, knob, knob, knob / 2f, 3f, 0x66000000);
			renderer.circle(handle, y + height / 2f, knob / 2f, 0xFFFFFFFF);
		}
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0 || !contains(mouseX, mouseY)) {
			return false;
		}
		float low = position(setting.low());
		float high = position(setting.high());
		dragging = Math.abs(mouseX - low) <= Math.abs(mouseX - high) ? 0 : 1;
		if (low == high) {
			dragging = mouseX < low ? 0 : 1;
		}
		update(mouseX);
		return true;
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		if (dragging < 0) {
			return false;
		}
		update(mouseX);
		return true;
	}

	@Override
	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		boolean was = dragging >= 0;
		dragging = -1;
		return was;
	}

	private void update(float mouseX) {
		double progress = MathUtil.clamp((mouseX - x) / Math.max(1f, width), 0f, 1f);
		double value = setting.min() + progress * (setting.max() - setting.min());
		if (dragging == 0) {
			setting.setLow(Math.min(value, setting.high()));
		} else {
			setting.setHigh(Math.max(value, setting.low()));
		}
	}
}
