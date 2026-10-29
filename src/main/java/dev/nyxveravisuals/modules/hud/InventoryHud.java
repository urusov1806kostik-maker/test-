package dev.nyxveravisuals.modules.hud;

import net.minecraft.client.Minecraft;
import net.minecraft.world.item.ItemStack;

import dev.nyxveravisuals.hud.HudAnchor;
import dev.nyxveravisuals.hud.HudContext;
import dev.nyxveravisuals.hud.PanelHudModule;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.util.ColorUtil;

/** The 27 main inventory slots. Reads the inventory directly each frame; nothing is copied or allocated. */
public final class InventoryHud extends PanelHudModule {
	private static final int COLUMNS = 9;
	private static final int ROWS = 3;
	private static final float CELL = 17;

	private final BooleanSetting slotBackgrounds = settings().add(new BooleanSetting("slot_backgrounds", true));

	public InventoryHud() {
		super("inventory", Category.HUD, false, HudAnchor.BOTTOM_RIGHT, -4, -44);
	}

	@Override
	protected boolean isPrivate() {
		return true;
	}

	@Override
	protected boolean hasContent(HudContext context) {
		return Minecraft.getInstance().player != null;
	}

	@Override
	protected void renderContent(HudContext context) {
		var player = Minecraft.getInstance().player;
		Renderer2D renderer = context.renderer();
		float width = COLUMNS * CELL + PADDING * 2 + 1;
		float height = ROWS * CELL + PADDING * 2 + 1;
		panel(context, width, height);
		for (int row = 0; row < ROWS; row++) {
			for (int column = 0; column < COLUMNS; column++) {
				float x = PADDING + 0.5f + column * CELL;
				float y = PADDING + 0.5f + row * CELL;
				if (slotBackgrounds.get()) {
					renderer.rounded(x + 0.5f, y + 0.5f, CELL - 1, CELL - 1, 2.5f, ColorUtil.withAlpha(context.theme().textPrimary(), 12));
				}
				if (player != null) {
					ItemStack stack = player.getInventory().getItem(9 + row * COLUMNS + column);
					renderer.itemWithOverlay(stack, x + 0.5f, y + 0.5f, 16);
				}
			}
		}
		setSize(width, height);
	}
}
