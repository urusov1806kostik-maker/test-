package dev.shadowvisuals.modules.funtime;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

import net.minecraft.client.Minecraft;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.core.registries.BuiltInRegistries;
import net.minecraft.resources.Identifier;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.world.entity.EquipmentSlot;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;

import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.AnimationClock;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.event.events.ClientTickEvent;
import dev.shadowvisuals.event.events.WorldLeaveEvent;
import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.modules.hud.ItemCounterHud;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.setting.SettingGroup;
import dev.shadowvisuals.setting.StringSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Universal warning banners: low health, low durability, missing important items and "cooldown ready".
 * Every warning has its own toggle, threshold and optional sound; states are evaluated once per tick and
 * a sound plays only when a warning starts, never repeatedly.
 */
public final class WarningsHud extends PanelHudModule {
	private enum Kind {
		LOW_HEALTH(Icon.WARNING),
		LOW_DURABILITY(Icon.TOOL),
		MISSING_ITEM(Icon.ERROR),
		COOLDOWN_READY(Icon.SUCCESS);

		final Icon icon;

		Kind(Icon icon) {
			this.icon = icon;
		}
	}

	private static final class Banner {
		final Kind kind;
		final Animation presence = new Animation(0f, DesignTokens.DURATION_NOTIFICATION, Easing.EASE_OUT_BACK);
		String text = "";
		boolean active;
		long until;

		Banner(Kind kind) {
			this.kind = kind;
		}
	}

	private final SettingGroup health = settings().add(new SettingGroup("low_health"));
	private final BooleanSetting healthEnabled = settings().add(health, new BooleanSetting("health_enabled", true));
	private final NumberSetting healthThreshold = settings().add(health, new NumberSetting("health_threshold", 8, 1, 19, 0.5)).dependsOn(healthEnabled);
	private final BooleanSetting healthSound = settings().add(health, new BooleanSetting("health_sound", true)).dependsOn(healthEnabled);

	private final SettingGroup durability = settings().add(new SettingGroup("low_durability"));
	private final BooleanSetting durabilityEnabled = settings().add(durability, new BooleanSetting("durability_enabled", true));
	private final NumberSetting durabilityThreshold = settings().add(durability, new NumberSetting("durability_threshold", 15, 1, 50, 1).suffix("%"))
		.dependsOn(durabilityEnabled);
	private final BooleanSetting durabilitySound = settings().add(durability, new BooleanSetting("durability_sound", false)).dependsOn(durabilityEnabled);

	private final SettingGroup missing = settings().add(new SettingGroup("missing_item"));
	private final BooleanSetting missingEnabled = settings().add(missing, new BooleanSetting("missing_enabled", true));
	private final StringSetting missingItems = settings().add(missing, new StringSetting("missing_items", "minecraft:totem_of_undying", 256))
		.dependsOn(missingEnabled);
	private final BooleanSetting missingSound = settings().add(missing, new BooleanSetting("missing_sound", false)).dependsOn(missingEnabled);

	private final SettingGroup cooldown = settings().add(new SettingGroup("cooldown_ready"));
	private final BooleanSetting cooldownEnabled = settings().add(cooldown, new BooleanSetting("cooldown_enabled", true));
	private final BooleanSetting cooldownSound = settings().add(cooldown, new BooleanSetting("cooldown_sound", true)).dependsOn(cooldownEnabled);

	private final Map<Kind, Banner> banners = new HashMap<>();
	private final List<Banner> visible = new ArrayList<>();
	private Set<Identifier> lastCooldowns = new HashSet<>();
	private final Map<Identifier, ItemStack> cooldownIcons = new HashMap<>();

	public WarningsHud() {
		super("warnings", Category.FUNTIME, false, HudAnchor.TOP_CENTER, 0, 40);
		for (Kind kind : Kind.values()) {
			banners.put(kind, new Banner(kind));
		}
		on(ClientTickEvent.class, event -> {
			if (!event.isPre()) {
				evaluate(Minecraft.getInstance());
			}
		});
		on(WorldLeaveEvent.class, event -> reset());
	}

	@Override
	protected void onDisable() {
		reset();
	}

	private void reset() {
		for (Banner banner : banners.values()) {
			banner.active = false;
			banner.presence.snapTo(0f);
		}
		lastCooldowns = new HashSet<>();
		cooldownIcons.clear();
	}

	private void evaluate(Minecraft minecraft) {
		var player = minecraft.player;
		if (player == null) {
			reset();
			return;
		}
		set(Kind.LOW_HEALTH, healthEnabled.get() && player.getHealth() + player.getAbsorptionAmount() <= healthThreshold.getFloat() && player.isAlive(),
			String.format(Locale.ROOT, "%.1f HP", player.getHealth() + player.getAbsorptionAmount()), healthSound.get());

		String worstItem = null;
		float worst = 2f;
		for (EquipmentSlot slot : EquipmentSlot.values()) {
			ItemStack stack = player.getItemBySlot(slot);
			if (stack.isEmpty() || !stack.isDamageableItem()) {
				continue;
			}
			float fraction = 1f - (float) stack.getDamageValue() / stack.getMaxDamage();
			if (fraction < worst) {
				worst = fraction;
				worstItem = stack.getHoverName().getString();
			}
		}
		set(Kind.LOW_DURABILITY, durabilityEnabled.get() && worstItem != null && worst * 100 <= durabilityThreshold.getFloat(),
			worstItem + " " + Math.round(worst * 100) + "%", durabilitySound.get());

		String missingName = null;
		if (missingEnabled.get()) {
			for (String part : missingItems.get().split(",")) {
				Identifier id = Identifier.tryParse(part.trim().toLowerCase(Locale.ROOT));
				if (id == null) {
					continue;
				}
				var holder = BuiltInRegistries.ITEM.get(id);
				if (holder.isPresent()) {
					Item item = holder.get().value();
					if (ItemCounterHud.count(minecraft, item) == 0) {
						missingName = new ItemStack(item).getHoverName().getString();
						break;
					}
				}
			}
		}
		set(Kind.MISSING_ITEM, missingName != null, missingName == null ? "" : missingName, missingSound.get());

		Set<Identifier> current = new HashSet<>(player.getCooldowns().cooldowns.keySet());
		if (cooldownEnabled.get()) {
			var inventory = player.getInventory();
			for (int slot = 0; slot < inventory.getContainerSize(); slot++) {
				ItemStack stack = inventory.getItem(slot);
				if (!stack.isEmpty()) {
					Identifier group = player.getCooldowns().getCooldownGroup(stack);
					if (current.contains(group)) {
						cooldownIcons.putIfAbsent(group, stack.copyWithCount(1));
					}
				}
			}
			for (Identifier finished : lastCooldowns) {
				if (!current.contains(finished)) {
					ItemStack icon = cooldownIcons.remove(finished);
					Banner banner = banners.get(Kind.COOLDOWN_READY);
					banner.text = icon == null ? finished.getPath() : icon.getHoverName().getString();
					banner.until = System.currentTimeMillis() + 1600;
					if (!banner.active && cooldownSound.get()) {
						playSound(minecraft, 1.6f);
					}
					banner.active = true;
				}
			}
		}
		lastCooldowns = current;
		Banner ready = banners.get(Kind.COOLDOWN_READY);
		if (ready.active && System.currentTimeMillis() > ready.until) {
			ready.active = false;
		}
	}

	private void set(Kind kind, boolean active, String text, boolean sound) {
		Banner banner = banners.get(kind);
		if (active && !banner.active && sound) {
			playSound(Minecraft.getInstance(), kind == Kind.LOW_HEALTH ? 0.7f : 1.1f);
		}
		banner.active = active;
		if (active) {
			banner.text = text;
		}
	}

	private static void playSound(Minecraft minecraft, float pitch) {
		minecraft.getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.NOTE_BLOCK_PLING.value(), pitch, 0.6f));
	}

	@Override
	protected boolean hasContent(HudContext context) {
		for (Banner banner : banners.values()) {
			if (banner.active || !banner.presence.isFinishedAtZero()) {
				return true;
			}
		}
		return false;
	}

	@Override
	protected void renderContent(HudContext context) {
		Renderer2D renderer = context.renderer();
		visible.clear();
		for (Kind kind : Kind.values()) {
			Banner banner = banners.get(kind);
			boolean show = banner.active || context.editing() && kind == Kind.LOW_HEALTH;
			banner.presence.animateTo(show ? 1f : 0f);
			if (banner.presence.value() > 0.001f) {
				visible.add(banner);
			}
		}
		float rowHeight = 16;
		float width = 110;
		for (Banner banner : visible) {
			width = Math.max(width, boldWidth(context, title(context, banner.kind)) + width(context, text(context, banner)) + 34);
		}
		float y = 0;
		double now = AnimationClock.global().now();
		for (Banner banner : visible) {
			float presence = banner.presence.value();
			int color = switch (banner.kind) {
				case LOW_HEALTH, MISSING_ITEM -> context.theme().error();
				case LOW_DURABILITY -> context.theme().warning();
				case COOLDOWN_READY -> context.theme().success();
			};
			float pulse = banner.kind == Kind.LOW_HEALTH ? (float) (0.75 + 0.25 * Math.sin(now * Math.PI * 3)) : 1f;
			renderer.pushAlpha(Math.min(1f, presence));
			renderer.push();
			renderer.scaleAround(0.9f + 0.1f * presence, width / 2f, y + rowHeight / 2f);
			renderer.shadow(0, y + 1, width, rowHeight, DesignTokens.RADIUS_M, 8, ColorUtil.withAlpha(0, 90));
			renderer.rounded(0, y, width, rowHeight, DesignTokens.RADIUS_M, ColorUtil.withAlpha(context.theme().panel(), Math.round(235 * opacity.getFloat() + 20)));
			renderer.rounded(0, y, width, rowHeight, DesignTokens.RADIUS_M, ColorUtil.withAlpha(color, Math.round(40 * pulse)));
			renderer.outline(0, y, width, rowHeight, DesignTokens.RADIUS_M, 1, ColorUtil.withAlpha(color, Math.round(160 * pulse)));
			banner.kind.icon.draw(renderer, 5, y + (rowHeight - 9) / 2f, 9, color);
			float textY = y + rowHeight / 2f - renderer.fonts().visualCenter(TEXT);
			String title = title(context, banner.kind);
			renderer.text(title, 18, textY, TEXT, context.theme().textPrimary(), FontManager.Weight.SEMIBOLD, false);
			renderer.text(text(context, banner), 18 + boldWidth(context, title) + 6, textY, TEXT, context.theme().textSecondary());
			renderer.pop();
			renderer.popAlpha();
			y += (rowHeight + 3) * Math.min(1f, presence);
		}
		setSize(width, Math.max(rowHeight, y));
	}

	private static String title(HudContext context, Kind kind) {
		return context.tr("hud.warning." + kind.name().toLowerCase(Locale.ROOT));
	}

	private static String text(HudContext context, Banner banner) {
		return banner.text.isEmpty() && context.editing() ? "6.0 HP" : banner.text;
	}
}
