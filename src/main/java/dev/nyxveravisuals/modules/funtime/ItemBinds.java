package dev.nyxveravisuals.modules.funtime;

import java.util.EnumMap;
import java.util.Locale;
import java.util.Map;

import net.minecraft.ChatFormatting;
import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.MultiPlayerGameMode;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.entity.player.Inventory;
import net.minecraft.world.inventory.ClickType;
import net.minecraft.world.item.ItemStack;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.event.events.KeyInputEvent;
import dev.nyxveravisuals.event.events.MouseButtonInputEvent;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.notification.NotificationManager;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.Keybind;
import dev.nyxveravisuals.setting.KeybindSetting;
import dev.nyxveravisuals.setting.SettingGroup;
import dev.nyxveravisuals.setting.StringSetting;

/**
 * One user-chosen key or mouse button per FunTime item. A press finds the item by its display name (hotbar
 * first, then off hand, then the main inventory), uses it once and puts the selected slot back. Every bind
 * starts unbound; names are editable in case the server renames an item. Nothing happens while a screen
 * (chat, inventory, menus) is open, and items on cooldown are not used.
 */
public final class ItemBinds extends Module {
	public enum Item {
		DISORIENTATION("disorientation", "Дезориентация"),
		LAYER("layer", "Пласт"),
		TRAP("trap", "Трапка"),
		EXPLICIT_DUST("explicit_dust", "Явная пыль"),
		FIRE_TORNADO("fire_tornado", "Огненный смерч");

		private final String id;
		private final String defaultName;

		Item(String id, String defaultName) {
			this.id = id;
			this.defaultName = defaultName;
		}
	}

	private static final long MIN_USE_INTERVAL_MILLIS = 150;
	private static final long NOTICE_INTERVAL_MILLIS = 1500;

	private final NyxveraClient client;
	private final Map<Item, KeybindSetting> binds = new EnumMap<>(Item.class);
	private final Map<Item, StringSetting> names = new EnumMap<>(Item.class);
	private final long[] lastUse = new long[Item.values().length];
	private final long[] lastNotice = new long[Item.values().length];
	private final BooleanSetting searchInventory = settings().add(new BooleanSetting("search_inventory", true));
	private final BooleanSetting notifyMissing = settings().add(new BooleanSetting("notify_missing", true));

	public ItemBinds(NyxveraClient client) {
		super("item_binds", Category.FUNTIME, true);
		this.client = client;
		for (Item item : Item.values()) {
			binds.put(item, settings().add(new KeybindSetting("bind_" + item.id, Keybind.NONE)));
		}
		SettingGroup nameGroup = settings().add(new SettingGroup("item_names", false));
		for (Item item : Item.values()) {
			names.put(item, settings().add(nameGroup, new StringSetting("name_" + item.id, item.defaultName, 48)));
		}
		on(KeyInputEvent.class, event -> {
			if (event.action() == 1) {
				onPress(Keybind.Device.KEYBOARD, event.key());
			}
		});
		on(MouseButtonInputEvent.class, event -> {
			if (event.action() == 1) {
				onPress(Keybind.Device.MOUSE, event.button());
			}
		});
	}

	public KeybindSetting bind(Item item) {
		return binds.get(item);
	}

	private void onPress(Keybind.Device device, int code) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.screen != null || minecraft.player == null || minecraft.gameMode == null) {
			return;
		}
		for (Item item : Item.values()) {
			if (binds.get(item).get().matches(device, code)) {
				use(item, minecraft.player, minecraft.gameMode);
			}
		}
	}

	private void use(Item item, LocalPlayer player, MultiPlayerGameMode gameMode) {
		long now = System.currentTimeMillis();
		if (now - lastUse[item.ordinal()] < MIN_USE_INTERVAL_MILLIS || player.isSpectator()) {
			return;
		}
		lastUse[item.ordinal()] = now;
		String pattern = normalize(names.get(item).get());
		if (pattern.isEmpty()) {
			return;
		}
		Inventory inventory = player.getInventory();
		int slot = find(inventory, pattern);
		if (slot < 0) {
			notice(item, "funtime.item_binds.missing");
			return;
		}
		if (player.getCooldowns().isOnCooldown(inventory.getItem(slot))) {
			notice(item, "funtime.item_binds.cooldown");
			return;
		}
		if (slot == Inventory.SLOT_OFFHAND) {
			gameMode.useItem(player, InteractionHand.OFF_HAND);
			return;
		}
		int selected = inventory.getSelectedSlot();
		if (Inventory.isHotbarSlot(slot)) {
			// The game sends the slot change before the use packet and restores it on the next tick.
			inventory.setSelectedSlot(slot);
			gameMode.useItem(player, InteractionHand.MAIN_HAND);
			inventory.setSelectedSlot(selected);
			return;
		}
		// Main inventory slots share their index with the player inventory menu; swap in, use, swap back.
		int container = player.inventoryMenu.containerId;
		gameMode.handleInventoryMouseClick(container, slot, selected, ClickType.SWAP, player);
		gameMode.useItem(player, InteractionHand.MAIN_HAND);
		gameMode.handleInventoryMouseClick(container, slot, selected, ClickType.SWAP, player);
	}

	private int find(Inventory inventory, String pattern) {
		int selected = inventory.getSelectedSlot();
		if (matches(inventory.getItem(selected), pattern)) {
			return selected;
		}
		for (int slot = 0; slot < Inventory.getSelectionSize(); slot++) {
			if (matches(inventory.getItem(slot), pattern)) {
				return slot;
			}
		}
		if (matches(inventory.getItem(Inventory.SLOT_OFFHAND), pattern)) {
			return Inventory.SLOT_OFFHAND;
		}
		if (searchInventory.get()) {
			for (int slot = Inventory.getSelectionSize(); slot < Inventory.INVENTORY_SIZE; slot++) {
				if (matches(inventory.getItem(slot), pattern)) {
					return slot;
				}
			}
		}
		return -1;
	}

	private static boolean matches(ItemStack stack, String pattern) {
		return !stack.isEmpty() && normalize(stack.getHoverName().getString()).contains(pattern);
	}

	/** Lower case, legacy color codes removed and whitespace collapsed, so decorated names still match. */
	public static String normalize(String text) {
		String plain = ChatFormatting.stripFormatting(text);
		return plain == null ? "" : plain.trim().replaceAll("\\s+", " ").toLowerCase(Locale.ROOT);
	}

	private void notice(Item item, String key) {
		long now = System.currentTimeMillis();
		if (!notifyMissing.get() || now - lastNotice[item.ordinal()] < NOTICE_INTERVAL_MILLIS) {
			return;
		}
		lastNotice[item.ordinal()] = now;
		client.notifications().push(NotificationManager.Type.WARNING, client.i18n().tr("module.item_binds.name"),
			client.i18n().tr(key, names.get(item).get()));
	}
}
