package dev.shadowvisuals.modules.iface;

import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.world.entity.HumanoidArm;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Rounded hotbar with a gliding selection indicator. Keeps the vanilla footprint (182x22 at the bottom
 * center) so health, hunger and experience bars stay aligned.
 */
public final class CustomHotbar extends Module {
	public enum Style {
		ROUNDED,
		SEPARATED,
		GLASS
	}

	private static final float WIDTH = 182;
	private static final float HEIGHT = 22;

	private final ShadowClient client;
	private final ModeSetting<Style> style = settings().add(new ModeSetting<>("hotbar_style", Style.ROUNDED));
	private final NumberSetting opacity = settings().add(new NumberSetting("background_opacity", 0.8, 0.1, 1.0, 0.05));
	private final NumberSetting scale = settings().add(new NumberSetting("scale", 1.0, 0.75, 1.25, 0.05).suffix("x"));
	private final BooleanSetting accentIndicator = settings().add(new BooleanSetting("accent_indicator", true));
	private final SmoothValue selected = new SmoothValue(-1f, 18f);

	public CustomHotbar(ShadowClient client) {
		super("custom_hotbar", Category.INTERFACE);
		this.client = client;
	}

	public void render(GuiGraphics graphics, DeltaTracker deltaTracker) {
		Minecraft minecraft = Minecraft.getInstance();
		Player player = minecraft.player;
		if (player == null || minecraft.gameMode == null || minecraft.options.hideGui) {
			return;
		}
		if (minecraft.player.isSpectator()) {
			return;
		}
		Renderer2D renderer = client.renderer().begin(graphics);
		ThemeManager theme = client.theme();
		float x = (graphics.guiWidth() - WIDTH) / 2f;
		float y = graphics.guiHeight() - HEIGHT;
		renderer.push();
		renderer.scaleAround(scale.getFloat(), graphics.guiWidth() / 2f, graphics.guiHeight());
		int fill = ColorUtil.withAlpha(style.get() == Style.GLASS ? ColorUtil.shade(theme.panel(), 0.06f) : theme.panel(),
			Math.round(255 * opacity.getFloat() * (style.get() == Style.GLASS ? 0.65f : 1f)));
		int slotFill = ColorUtil.withAlpha(theme.textPrimary(), 14);
		if (style.get() == Style.SEPARATED) {
			for (int i = 0; i < 9; i++) {
				renderer.rounded(x + 1 + i * 20, y + 1, 20, 20, DesignTokens.RADIUS_M, fill);
			}
		} else {
			renderer.shadow(x, y + 1, WIDTH, HEIGHT - 1, DesignTokens.RADIUS_L, 8, ColorUtil.withAlpha(0, Math.round(110 * opacity.getFloat())));
			renderer.rounded(x, y, WIDTH, HEIGHT - 1, DesignTokens.RADIUS_L, fill);
			renderer.outline(x, y, WIDTH, HEIGHT - 1, DesignTokens.RADIUS_L, 1, ColorUtil.withAlpha(theme.border(), Math.round(255 * opacity.getFloat())));
			for (int i = 0; i < 9; i++) {
				renderer.rounded(x + 2 + i * 20, y + 2, 18, 17, DesignTokens.RADIUS_S, slotFill);
			}
		}
		int target = player.getInventory().getSelectedSlot();
		if (selected.target() < 0) {
			selected.snap(target);
		}
		selected.setTarget(target);
		float indicatorX = x + 1 + selected.get() * 20;
		if (accentIndicator.get()) {
			renderer.rounded(indicatorX, y, 20, HEIGHT - 1, DesignTokens.RADIUS_M, theme.accentMuted(60));
			renderer.outline(indicatorX, y, 20, HEIGHT - 1, DesignTokens.RADIUS_M, 1, theme.accent());
		} else {
			renderer.outline(indicatorX, y, 20, HEIGHT - 1, DesignTokens.RADIUS_M, 1, ColorUtil.withAlpha(theme.textPrimary(), 200));
		}
		for (int i = 0; i < 9; i++) {
			renderer.itemWithOverlay(player.getInventory().getItem(i), x + 3 + i * 20, y + 2.5f, 16);
		}
		ItemStack offhand = player.getOffhandItem();
		if (!offhand.isEmpty()) {
			boolean left = player.getMainArm().getOpposite() == HumanoidArm.LEFT;
			float offX = left ? x - 26 : x + WIDTH + 4;
			renderer.rounded(offX, y, 22, HEIGHT - 1, DesignTokens.RADIUS_L, fill);
			renderer.outline(offX, y, 22, HEIGHT - 1, DesignTokens.RADIUS_L, 1, ColorUtil.withAlpha(theme.border(), Math.round(255 * opacity.getFloat())));
			renderer.itemWithOverlay(offhand, offX + 3, y + 2.5f, 16);
		}
		renderer.pop();
	}
}
