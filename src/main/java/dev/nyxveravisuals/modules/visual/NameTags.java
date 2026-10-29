package dev.nyxveravisuals.modules.visual;

import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.PlayerInfo;
import net.minecraft.util.Mth;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.event.events.HudRenderEvent;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.WorldProjection;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.util.ColorUtil;
import dev.nyxveravisuals.util.Numbers;

/**
 * Clean player name tags drawn in screen space: name, health, distance, ping, held item and armor. Size is
 * kept between a minimum and maximum so tags never become huge up close or unreadable far away. The vanilla
 * player name tag is hidden while this is on.
 */
public final class NameTags extends Module {
	private static final EquipmentSlot[] ARMOR = {EquipmentSlot.HEAD, EquipmentSlot.CHEST, EquipmentSlot.LEGS, EquipmentSlot.FEET};

	private final NyxveraClient client;
	private final BooleanSetting health = settings().add(new BooleanSetting("show_health", true));
	private final BooleanSetting distance = settings().add(new BooleanSetting("show_distance", true));
	private final BooleanSetting ping = settings().add(new BooleanSetting("show_ping", false));
	private final BooleanSetting heldItem = settings().add(new BooleanSetting("show_held_item", true));
	private final BooleanSetting armor = settings().add(new BooleanSetting("show_armor", false));
	private final NumberSetting scale = settings().add(new NumberSetting("scale", 1.0, 0.5, 2.0, 0.05).suffix("x"));
	private final NumberSetting maxDistance = settings().add(new NumberSetting("max_distance", 64, 8, 256, 4).suffix("m"));
	private final NumberSetting opacity = settings().add(new NumberSetting("background_opacity", 0.75, 0.0, 1.0, 0.05));
	private final WorldProjection.ScreenPoint point = new WorldProjection.ScreenPoint();
	private final StringBuilder line = new StringBuilder(48);

	public NameTags(NyxveraClient client) {
		super("name_tags", Category.VISUAL);
		this.client = client;
		on(HudRenderEvent.class, this::render);
	}

	/** Used by the name-tag mixin to hide the vanilla tag of players. */
	public boolean hidesVanilla() {
		return isEnabled();
	}

	private void render(HudRenderEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.level == null || minecraft.player == null || !client.projection().isValid()) {
			return;
		}
		Renderer2D renderer = event.renderer();
		double max = maxDistance.getDouble();
		for (Player player : minecraft.level.players()) {
			if (player == minecraft.player || !player.isAlive() || player.isInvisible()) {
				continue;
			}
			double distanceSquared = minecraft.player.distanceToSqr(player);
			if (distanceSquared > max * max) {
				continue;
			}
			float partial = event.partialTick();
			double x = Mth.lerp(partial, player.xo, player.getX());
			double y = Mth.lerp(partial, player.yo, player.getY()) + player.getBbHeight() + 0.45;
			double z = Mth.lerp(partial, player.zo, player.getZ());
			if (!client.projection().project(x, y, z, point) || point.x < -60 || point.x > event.width() + 60 || point.y < -40 || point.y > event.height() + 40) {
				continue;
			}
			float dist = (float) Math.sqrt(distanceSquared);
			float size = scale.getFloat() * Mth.clamp(1.6f - dist / 40f, 0.75f, 1.35f);
			drawTag(event, renderer, player, point.x, point.y, size, dist, minecraft);
		}
	}

	private void drawTag(HudRenderEvent event, Renderer2D renderer, Player player, float centerX, float bottomY, float size, float dist, Minecraft minecraft) {
		var theme = client.theme();
		boolean friend = client.friends().isFriend(player.getGameProfile().name());
		String name = player.getName().getString();
		float text = DesignTokens.FONT_SMALL;
		line.setLength(0);
		if (distance.get()) {
			Numbers.appendFixed(line, dist, 0).append('m');
		}
		if (ping.get() && minecraft.getConnection() != null) {
			PlayerInfo info = minecraft.getConnection().getPlayerInfo(player.getUUID());
			if (info != null) {
				line.append(line.isEmpty() ? "" : "  ").append(info.getLatency()).append("ms");
			}
		}
		String details = line.toString();
		String healthText = health.get() ? Numbers.fixed(player.getHealth() + player.getAbsorptionAmount(), 1) : null;
		float nameWidth = renderer.textWidth(name, text, FontManager.Weight.SEMIBOLD);
		float healthWidth = healthText == null ? 0 : renderer.textWidth(healthText, text, FontManager.Weight.SEMIBOLD) + 5;
		float detailsWidth = details.isEmpty() ? 0 : renderer.textWidth(details, DesignTokens.FONT_CAPTION) + 5;
		float width = nameWidth + healthWidth + detailsWidth + 10;
		float height = renderer.lineHeight(text) + 4;
		renderer.push();
		renderer.translate(centerX, bottomY);
		renderer.scale(size);
		float left = -width / 2f;
		float top = -height;
		renderer.rounded(left, top, width, height, DesignTokens.RADIUS_S, ColorUtil.withAlpha(theme.panel(), Math.round(255 * opacity.getFloat())));
		if (friend) {
			renderer.outline(left, top, width, height, DesignTokens.RADIUS_S, 1, ColorUtil.withAlpha(theme.success(), 180));
		}
		float textY = top + height / 2f - renderer.fonts().visualCenter(text);
		float cursor = left + 5;
		renderer.text(name, cursor, textY, text, friend ? theme.success() : theme.textPrimary(), FontManager.Weight.SEMIBOLD, false);
		cursor += nameWidth + 5;
		if (healthText != null) {
			float fraction = Mth.clamp(player.getHealth() / Math.max(1f, player.getMaxHealth()), 0f, 1f);
			renderer.text(healthText, cursor, textY, text, ColorUtil.lerp(theme.error(), theme.success(), fraction), FontManager.Weight.SEMIBOLD, false);
			cursor += healthWidth;
		}
		if (!details.isEmpty()) {
			renderer.text(details, cursor, top + height / 2f - renderer.fonts().visualCenter(DesignTokens.FONT_CAPTION), DesignTokens.FONT_CAPTION,
				theme.textSecondary());
		}
		float itemsY = top - 13;
		float itemX = -((armor.get() ? 4 : 0) + (heldItem.get() ? 1 : 0)) * 13 / 2f;
		if (heldItem.get()) {
			ItemStack held = player.getMainHandItem();
			if (!held.isEmpty()) {
				renderer.item(held, itemX, itemsY, 12);
			}
			itemX += 13;
		}
		if (armor.get()) {
			for (EquipmentSlot slot : ARMOR) {
				ItemStack stack = player.getItemBySlot(slot);
				if (!stack.isEmpty()) {
					renderer.item(stack, itemX, itemsY, 12);
				}
				itemX += 13;
			}
		}
		renderer.pop();
	}
}
