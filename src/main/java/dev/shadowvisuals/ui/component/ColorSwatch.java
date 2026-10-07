package dev.shadowvisuals.ui.component;

import dev.shadowvisuals.core.UiSounds;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.ui.overlay.ColorPickerOverlay;
import dev.shadowvisuals.util.ColorUtil;

/** Color preview chip that opens the shared {@link ColorPickerOverlay}. */
public final class ColorSwatch extends Component {
	private final ColorSetting setting;

	public ColorSwatch(ColorSetting setting) {
		this.setting = setting;
		setBounds(0, 0, 22, DesignTokens.CONTROL_HEIGHT - 2);
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		int color = setting.color();
		if (ColorUtil.alpha(color) < 255) {
			renderer.rounded(x, y, width, height, DesignTokens.RADIUS_S, 0xFFCFCFCF);
			renderer.rounded(x, y, width / 2f, height / 2f, DesignTokens.RADIUS_S, 0xFFA0A0A0);
			renderer.rounded(x + width / 2f, y + height / 2f, width / 2f, height / 2f, DesignTokens.RADIUS_S, 0xFFA0A0A0);
		}
		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_S, color);
		renderer.outline(x, y, width, height, DesignTokens.RADIUS_S, 1,
			ColorUtil.lerp(context.theme().border(), context.theme().textSecondary(), hover() * 0.6f));
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (button != 0 || !contains(mouseX, mouseY)) {
			return false;
		}
		context.sounds().play(UiSounds.Kind.CLICK);
		context.overlays().open(new ColorPickerOverlay(this, setting));
		return true;
	}
}
