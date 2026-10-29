package dev.nyxveravisuals.ui.component;

import org.lwjgl.glfw.GLFW;

import dev.nyxveravisuals.animation.Animation;
import dev.nyxveravisuals.animation.Easing;
import dev.nyxveravisuals.animation.SmoothValue;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.util.ColorUtil;
import dev.nyxveravisuals.util.MathUtil;

/** Horizontal slider for any {@link Model}; the fill glides smoothly to the snapped value while dragging. */
public final class Slider extends Component {
	public interface Model {
		double progress();

		void setProgress(double progress);

		/** Moves by {@code steps} increments (arrow keys / fine adjustment). */
		void step(int steps);
	}

	private final Model model;
	private final SmoothValue shown;
	private final Animation knobGrow = new Animation(0f, DesignTokens.DURATION_HOVER, Easing.EASE_OUT_QUAD);
	private boolean dragging;

	public Slider(Model model) {
		this.model = model;
		this.shown = new SmoothValue((float) model.progress(), 22f);
		setBounds(0, 0, 80, DesignTokens.SLIDER_KNOB + 2);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		shown.setTarget((float) model.progress());
		float progress = MathUtil.clamp(shown.get(), 0f, 1f);
		knobGrow.animateTo(dragging || isHovered() ? 1f : 0f);

		float track = DesignTokens.SLIDER_TRACK;
		float trackY = y + (height - track) / 2f;
		renderer.rounded(x, trackY, width, track, track / 2f, ColorUtil.shade(theme.border(), 0.05f));
		float filled = width * progress;
		if (filled > 0.5f) {
			renderer.gradientHorizontal(x, trackY, filled, track, track / 2f, theme.accent(), ColorUtil.lerp(theme.accent(), theme.accentSecondary(), 0.6f));
		}
		float knob = DesignTokens.SLIDER_KNOB * (0.85f + 0.15f * knobGrow.value());
		float knobX = x + filled;
		if (knobGrow.value() > 0.01f) {
			renderer.circle(knobX, y + height / 2f, knob / 2f + 3f * knobGrow.value(), theme.accentMuted(Math.round(50 * knobGrow.value())));
		}
		renderer.shadow(knobX - knob / 2f, y + height / 2f - knob / 2f + 0.5f, knob, knob, knob / 2f, 3f, 0x66000000);
		renderer.circle(knobX, y + height / 2f, knob / 2f, 0xFFFFFFFF);
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0 || !contains(mouseX, mouseY)) {
			return false;
		}
		dragging = true;
		update(mouseX);
		return true;
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		if (!dragging) {
			return false;
		}
		update(mouseX);
		return true;
	}

	@Override
	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		boolean was = dragging;
		dragging = false;
		return was;
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		if (!isHovered()) {
			return false;
		}
		if (key == GLFW.GLFW_KEY_LEFT || key == GLFW.GLFW_KEY_RIGHT) {
			model.step(key == GLFW.GLFW_KEY_RIGHT ? 1 : -1);
			return true;
		}
		return false;
	}

	public boolean isDragging() {
		return dragging;
	}

	private void update(float mouseX) {
		model.setProgress(MathUtil.clamp((mouseX - x) / Math.max(1f, width), 0f, 1f));
	}
}
