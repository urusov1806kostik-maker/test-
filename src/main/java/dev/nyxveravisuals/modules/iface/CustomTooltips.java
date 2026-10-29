package dev.nyxveravisuals.modules.iface;

import net.minecraft.client.gui.GuiGraphics;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.util.ColorUtil;

/** Draws item and GUI tooltips on the NyxveraVisuals surface instead of the vanilla frame. */
public final class CustomTooltips extends Module {
	private final NyxveraClient client;
	private final NumberSetting opacity = settings().add(new NumberSetting("background_opacity", 0.95, 0.3, 1.0, 0.05));
	private final BooleanSetting accentBorder = settings().add(new BooleanSetting("accent_border", true));

	public CustomTooltips(NyxveraClient client) {
		super("custom_tooltips", Category.INTERFACE);
		this.client = client;
	}

	/** Content box is {@code (x, y, width, height)}; the panel extends 3 units around it like vanilla. */
	public void drawBackground(GuiGraphics graphics, int x, int y, int width, int height) {
		Renderer2D renderer = client.renderer().begin(graphics);
		var theme = client.theme();
		float left = x - 4;
		float top = y - 4;
		float panelWidth = width + 8;
		float panelHeight = height + 8;
		renderer.shadow(left, top + 1, panelWidth, panelHeight, DesignTokens.RADIUS_M, 8, ColorUtil.withAlpha(0, 110));
		renderer.rounded(left, top, panelWidth, panelHeight, DesignTokens.RADIUS_M, ColorUtil.withAlpha(theme.panel(), Math.round(255 * opacity.getFloat())));
		renderer.outline(left, top, panelWidth, panelHeight, DesignTokens.RADIUS_M, 1,
			accentBorder.get() ? theme.accentMuted(150) : theme.border());
	}
}
