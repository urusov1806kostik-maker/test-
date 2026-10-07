package dev.shadowvisuals.modules.visual;

import net.minecraft.client.Minecraft;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.item.ItemEntity;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Rarity;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.event.events.HudRenderEvent;
import dev.shadowvisuals.event.events.WorldRenderEvent;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.WorldProjection;
import dev.shadowvisuals.render.WorldRenderer3D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.util.ColorUtil;

/** Labels (and optional boxes) for dropped items, filtered by rarity and distance. */
public final class ItemEsp extends Module {
	public enum MinRarity {
		COMMON,
		UNCOMMON,
		RARE,
		EPIC
	}

	private final ShadowClient client;
	private final ModeSetting<MinRarity> minRarity = settings().add(new ModeSetting<>("min_rarity", MinRarity.COMMON));
	private final BooleanSetting enchantedOnly = settings().add(new BooleanSetting("enchanted_only", false));
	private final NumberSetting maxDistance = settings().add(new NumberSetting("max_distance", 32, 4, 128, 2).suffix("m"));
	private final BooleanSetting labels = settings().add(new BooleanSetting("labels", true));
	private final BooleanSetting boxes = settings().add(new BooleanSetting("boxes", false));
	private final WorldProjection.ScreenPoint point = new WorldProjection.ScreenPoint();

	public ItemEsp(ShadowClient client) {
		super("item_esp", Category.VISUAL);
		this.client = client;
		on(HudRenderEvent.class, this::render2d);
		on(WorldRenderEvent.class, this::render3d);
	}

	private boolean shown(ItemEntity item, Minecraft minecraft) {
		ItemStack stack = item.getItem();
		if (stack.isEmpty() || minecraft.player == null) {
			return false;
		}
		double max = maxDistance.getDouble();
		if (minecraft.player.distanceToSqr(item) > max * max) {
			return false;
		}
		if (enchantedOnly.get() && !stack.isEnchanted()) {
			return false;
		}
		return stack.getRarity().ordinal() >= minRarity.get().ordinal();
	}

	private int rarityColor(ItemStack stack) {
		Rarity rarity = stack.getRarity();
		return switch (rarity) {
			case UNCOMMON -> 0xFFF5D244;
			case RARE -> 0xFF5BD8F2;
			case EPIC -> 0xFFD07CF6;
			default -> client.theme().textPrimary();
		};
	}

	private void render3d(WorldRenderEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
		if (!boxes.get() || minecraft.level == null) {
			return;
		}
		for (Entity entity : minecraft.level.entitiesForRendering()) {
			if (entity instanceof ItemEntity item && shown(item, minecraft)) {
				int color = rarityColor(item.getItem());
				WorldRenderer3D.boxOutline(event.frame(), PlayerEsp.interpolatedBox(item, event.frame().partialTick()), ColorUtil.withAlpha(color, 200), 1.5f, false);
			}
		}
	}

	private void render2d(HudRenderEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
		if (!labels.get() || minecraft.level == null || !client.projection().isValid()) {
			return;
		}
		Renderer2D renderer = event.renderer();
		float size = DesignTokens.FONT_CAPTION;
		for (Entity entity : minecraft.level.entitiesForRendering()) {
			if (!(entity instanceof ItemEntity item) || !shown(item, minecraft)) {
				continue;
			}
			float partial = event.partialTick();
			double x = Mth.lerp(partial, item.xo, item.getX());
			double y = Mth.lerp(partial, item.yo, item.getY()) + 0.6;
			double z = Mth.lerp(partial, item.zo, item.getZ());
			if (!client.projection().project(x, y, z, point) || point.x < -40 || point.x > event.width() + 40 || point.y < -20 || point.y > event.height() + 20) {
				continue;
			}
			ItemStack stack = item.getItem();
			String label = stack.getHoverName().getString() + (stack.getCount() > 1 ? " ×" + stack.getCount() : "");
			float width = renderer.textWidth(label, size) + 8;
			float height = renderer.lineHeight(size) + 3;
			renderer.rounded(point.x - width / 2f, point.y - height, width, height, DesignTokens.RADIUS_XS, ColorUtil.withAlpha(client.theme().panel(), 190));
			renderer.text(label, point.x, point.y - height / 2f - renderer.fonts().visualCenter(size), size, rarityColor(stack), Renderer2D.Align.CENTER);
		}
	}
}
