package dev.shadowvisuals.ui.component;

import java.util.function.BooleanSupplier;
import java.util.function.Consumer;

import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.core.UiSounds;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.util.ColorUtil;

/** Pill switch. State lives in the model (getter/setter); the widget only animates towards it. */
public final class Toggle extends Component {
	private final BooleanSupplier getter;
	private final Consumer<Boolean> setter;
	private final Animation knob;

	public Toggle(BooleanSupplier getter, Consumer<Boolean> setter) {
		this.getter = getter;
		this.setter = setter;
		this.knob = new Animation(getter.getAsBoolean() ? 1f : 0f, DesignTokens.DURATION_TOGGLE, Easing.EASE_OUT_BACK);
		setBounds(0, 0, DesignTokens.TOGGLE_WIDTH, DesignTokens.TOGGLE_HEIGHT);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		knob.animateTo(getter.getAsBoolean() ? 1f : 0f);
		drawSwitch(context, x, y, width, height, knob.value(), hover());
	}

	/** Shared switch painter (also used by module cards) so every switch looks identical. */
	public static void drawSwitch(UiContext context, float x, float y, float width, float height, float progress, float hover) {
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		float on = Math.max(0f, Math.min(1f, progress));
		int offTrack = ColorUtil.shade(theme.border(), 0.04f + hover * 0.04f);
		int onTrack = theme.enabled();
		int track = ColorUtil.lerp(offTrack, onTrack, on);
		int trackEnd = ColorUtil.lerp(offTrack, ColorUtil.lerp(onTrack, theme.accentSecondary(), 0.55f), on);
		float radius = height / 2f;
		renderer.gradientHorizontal(x, y, width, height, radius, track, trackEnd);
		float inset = 1.5f;
		float knobSize = height - inset * 2;
		float travel = width - knobSize - inset * 2;
		float knobX = x + inset + travel * progress;
		renderer.shadow(knobX, y + inset + 0.5f, knobSize, knobSize, knobSize / 2f, 2.5f, 0x55000000);
		renderer.circle(knobX + knobSize / 2f, y + height / 2f, knobSize / 2f, ColorUtil.lerp(0xFFB9BDC9, 0xFFFFFFFF, on));
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0 || !contains(mouseX, mouseY)) {
			return false;
		}
		boolean next = !getter.getAsBoolean();
		setter.accept(next);
		context.sounds().play(next ? UiSounds.Kind.TOGGLE_ON : UiSounds.Kind.TOGGLE_OFF);
		return true;
	}
}
