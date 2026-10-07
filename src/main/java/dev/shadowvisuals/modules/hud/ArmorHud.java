package dev.shadowvisuals.modules.hud;

import net.minecraft.client.Minecraft;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.item.ItemStack;

import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.util.ColorUtil;

/** Worn armor (and optionally held items) with durability bars; low durability is highlighted. */
public final class ArmorHud extends PanelHudModule {
	public enum Layout {
		HORIZONTAL,
		VERTICAL
	}

	private static final EquipmentSlot[] ARMOR = {EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET};
	private static final EquipmentSlot[] WITH_HANDS = {EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET,
		EquipmentSlot.MAINHAND, EquipmentSlot.OFFHAND};

	private final ModeSetting<Layout> layout = settings().add(new ModeSetting<>("layout", Layout.HORIZONTAL));
	private final BooleanSetting percentage = settings().add(new BooleanSetting("percentage", false));
	private final BooleanSetting hands = settings().add(new BooleanSetting("include_hands", false));
	private final NumberSetting lowThreshold = settings().add(new NumberSetting("low_threshold", 20, 1, 60, 1).suffix("%"));

	public ArmorHud() {
		super("armor", Category.HUD, false, HudAnchor.BOTTOM_CENTER, 98, -4);
	}

	@Override
	protected boolean hasContent(HudContext context) {
		var player = Minecraft.getInstance().player;
		if (player == null) {
			return false;
		}
		for (EquipmentSlot slot : slots()) {
			if (!player.getItemBySlot(slot).isEmpty()) {
				return true;
			}
		}
		return false;
	}

	private EquipmentSlot[] slots() {
		return hands.get() ? WITH_HANDS : ARMOR;
	}

	@Override
	protected void renderContent(HudContext context) {
		var player = Minecraft.getInstance().player;
		Renderer2D renderer = context.renderer();
		ThemeManager theme = context.theme();
		EquipmentSlot[] slots = slots();
		boolean horizontal = layout.get() == Layout.HORIZONTAL;
		float cell = 18;
		float labelHeight = percentage.get() ? 8 : 0;
		float cellHeight = cell + 3 + labelHeight;
		float width = horizontal ? slots.length * cell + PADDING * 2 : cell + PADDING * 2 + (percentage.get() ? 22 : 0);
		float height = horizontal ? cellHeight + PADDING * 2 - 2 : slots.length * (cell + 3) + PADDING * 2 - 2;
		panel(context, width, height);
		for (int i = 0; i < slots.length; i++) {
			ItemStack stack = player == null ? ItemStack.EMPTY : player.getItemBySlot(slots[i]);
			float x = horizontal ? PADDING + i * cell : PADDING;
			float y = horizontal ? PADDING - 1 : PADDING - 1 + i * (cell + 3);
			renderer.rounded(x + 1, y + 1, cell - 2, cell - 2, 3, ColorUtil.withAlpha(theme.textPrimary(), 10));
			if (stack.isEmpty()) {
				continue;
			}
			renderer.item(stack, x + 1, y + 1, 16);
			if (!stack.isDamageableItem()) {
				continue;
			}
			float fraction = 1f - (float) stack.getDamageValue() / stack.getMaxDamage();
			boolean low = fraction * 100f <= lowThreshold.getFloat();
			int color = low ? theme.error() : ColorUtil.lerp(theme.warning(), theme.success(), Math.min(1f, fraction * 1.6f));
			renderer.rounded(x + 2, y + cell, cell - 4, 1.6f, 0.8f, ColorUtil.withAlpha(theme.textPrimary(), 30));
			renderer.rounded(x + 2, y + cell, (cell - 4) * fraction, 1.6f, 0.8f, color);
			if (percentage.get()) {
				String label = Math.round(fraction * 100) + "%";
				float size = 6f;
				if (horizontal) {
					renderer.text(label, x + cell / 2f, y + cell + 2.5f, size, low ? theme.error() : theme.textSecondary(), Renderer2D.Align.CENTER);
				} else {
					renderer.text(label, x + cell + 3, y + cell / 2f - 3, size, low ? theme.error() : theme.textSecondary());
				}
			}
		}
		setSize(width, height);
	}
}
