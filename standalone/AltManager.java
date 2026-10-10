package dev.shadowclient.gui;

import java.io.IOException;
import java.lang.reflect.Field;
import java.lang.reflect.Modifier;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;

import com.google.gson.GsonBuilder;
import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

import net.minecraft.client.Minecraft;
import net.minecraft.client.User;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.core.UUIDUtil;
import net.minecraft.network.chat.Component;

import net.fabricmc.loader.api.FabricLoader;

/**
 * Self-contained offline (no-password) account switcher. Needs only Minecraft 1.21.11 (Mojang mappings), Fabric
 * Loader and Gson: no access widener, no mixin, no other client classes.
 *
 * <p>Open it from your ClickGUI (button, module action, keybind) with {@code AltManager.open()}. Nicknames are
 * saved in {@code config/shadowclient/alts.json}. Switching works only outside a world. Microsoft passwords and
 * tokens are never asked for or stored; offline nicknames work on servers that accept any name.
 */
public final class AltManager {
	private static final Pattern VALID_NAME = Pattern.compile("[A-Za-z0-9_]{3,16}");
	private static final int MAX_ALTS = 100;
	private static final List<String> ALTS = new ArrayList<>();
	private static User original;
	private static boolean loaded;
	private static Field userField;

	private AltManager() {
	}

	/** Opens the alt manager on top of the current screen (your ClickGUI returns when it is closed). */
	public static void open() {
		Minecraft minecraft = Minecraft.getInstance();
		minecraft.setScreen(new AltScreen(minecraft.screen));
	}

	public static List<String> alts() {
		load();
		return List.copyOf(ALTS);
	}

	public static boolean add(String name) {
		load();
		if (!VALID_NAME.matcher(name).matches() || ALTS.contains(name) || ALTS.size() >= MAX_ALTS) {
			return false;
		}
		ALTS.add(name);
		save();
		return true;
	}

	public static boolean remove(String name) {
		load();
		boolean removed = ALTS.remove(name);
		if (removed) {
			save();
		}
		return removed;
	}

	/** Switches the session to the offline account {@code name}. Returns false inside a world or for bad names. */
	public static boolean login(String name) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.level != null || !VALID_NAME.matcher(name).matches()) {
			return false;
		}
		if (original == null) {
			original = minecraft.getUser();
		}
		return setUser(new User(name, UUIDUtil.createOfflinePlayerUUID(name), "", Optional.empty(), Optional.empty()));
	}

	/** Returns to the account the game was started with. */
	public static boolean restore() {
		if (original == null || Minecraft.getInstance().level != null) {
			return false;
		}
		boolean done = setUser(original);
		if (done) {
			original = null;
		}
		return done;
	}

	/**
	 * Minecraft keeps the session in a private final field. It is found by type, not by name, so this works both in
	 * development and in the obfuscated (intermediary) production game.
	 */
	private static boolean setUser(User user) {
		try {
			if (userField == null) {
				for (Field field : Minecraft.class.getDeclaredFields()) {
					if (field.getType() == User.class && !Modifier.isStatic(field.getModifiers())) {
						field.setAccessible(true);
						userField = field;
						break;
					}
				}
			}
			if (userField == null) {
				return false;
			}
			userField.set(Minecraft.getInstance(), user);
			return true;
		} catch (ReflectiveOperationException | RuntimeException e) {
			System.err.println("[AltManager] Could not switch account: " + e);
			return false;
		}
	}

	private static Path file() {
		return FabricLoader.getInstance().getConfigDir().resolve("shadowclient").resolve("alts.json");
	}

	private static void load() {
		if (loaded) {
			return;
		}
		loaded = true;
		Path file = file();
		if (!Files.isRegularFile(file)) {
			return;
		}
		try {
			JsonElement root = JsonParser.parseString(Files.readString(file, StandardCharsets.UTF_8));
			if (root.isJsonObject() && root.getAsJsonObject().has("alts")) {
				for (JsonElement element : root.getAsJsonObject().getAsJsonArray("alts")) {
					String name = element.getAsString();
					if (VALID_NAME.matcher(name).matches() && !ALTS.contains(name) && ALTS.size() < MAX_ALTS) {
						ALTS.add(name);
					}
				}
			}
		} catch (IOException | RuntimeException e) {
			System.err.println("[AltManager] Could not read " + file + ": " + e);
		}
	}

	private static void save() {
		JsonObject json = new JsonObject();
		JsonArray list = new JsonArray();
		ALTS.forEach(list::add);
		json.add("alts", list);
		Path file = file();
		try {
			Files.createDirectories(file.getParent());
			Path temp = file.resolveSibling("alts.json.tmp");
			Files.writeString(temp, new GsonBuilder().setPrettyPrinting().create().toJson(json), StandardCharsets.UTF_8);
			Files.move(temp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
		} catch (IOException e) {
			System.err.println("[AltManager] Could not save " + file + ": " + e);
		}
	}

	/** Dark panel with the nickname list, an input field and actions. */
	private static final class AltScreen extends Screen {
		private static final int PANEL_WIDTH = 240;
		private static final int ROW = 16;
		private final Screen parent;
		private EditBox input;
		private String status = "";
		private int selected = -1;
		private int scroll;

		AltScreen(Screen parent) {
			super(Component.literal("Alt Manager"));
			this.parent = parent;
		}

		private int left() {
			return (width - PANEL_WIDTH) / 2;
		}

		private int listTop() {
			return 52;
		}

		private int listBottom() {
			return height - 84;
		}

		private int visibleRows() {
			return Math.max(1, (listBottom() - listTop()) / ROW);
		}

		@Override
		protected void init() {
			load();
			int x = left() + 10;
			int inner = PANEL_WIDTH - 20;
			input = new EditBox(font, x, height - 76, inner, 18, Component.literal("Nickname"));
			input.setMaxLength(16);
			input.setHint(Component.literal("Nickname (3-16: A-Z 0-9 _)"));
			addRenderableWidget(input);
			int third = (inner - 8) / 3;
			addRenderableWidget(Button.builder(Component.literal("Add"), b -> addTyped()).bounds(x, height - 54, third, 20).build());
			addRenderableWidget(Button.builder(Component.literal("Log in"), b -> loginSelected()).bounds(x + third + 4, height - 54, third, 20).build());
			addRenderableWidget(Button.builder(Component.literal("Remove"), b -> removeSelected()).bounds(x + (third + 4) * 2, height - 54, third, 20).build());
			int half = (inner - 4) / 2;
			addRenderableWidget(Button.builder(Component.literal("Original account"), b -> status = restore()
				? "Back to " + minecraft.getUser().getName() : minecraft.level != null ? "Leave the world first" : "Already on the original account")
				.bounds(x, height - 30, half, 20).build());
			addRenderableWidget(Button.builder(Component.literal("Done"), b -> onClose()).bounds(x + half + 4, height - 30, half, 20).build());
			setInitialFocus(input);
		}

		private void addTyped() {
			String name = input.getValue().strip();
			if (add(name)) {
				selected = ALTS.size() - 1;
				input.setValue("");
				status = "Added " + name;
			} else {
				status = VALID_NAME.matcher(name).matches() ? "Already added or list full" : "Invalid nickname";
			}
		}

		private void loginSelected() {
			String name = selected >= 0 && selected < ALTS.size() ? ALTS.get(selected) : input.getValue().strip();
			if (minecraft.level != null) {
				status = "Leave the world first";
			} else if (login(name)) {
				status = "Logged in as " + name;
			} else {
				status = "Select or type a valid nickname";
			}
		}

		private void removeSelected() {
			if (selected >= 0 && selected < ALTS.size()) {
				String name = ALTS.get(selected);
				remove(name);
				selected = -1;
				scroll = Math.max(0, Math.min(scroll, ALTS.size() - visibleRows()));
				status = "Removed " + name;
			}
		}

		@Override
		public boolean mouseClicked(MouseButtonEvent event, boolean doubleClick) {
			int row = (int) ((event.y() - listTop()) / ROW) + scroll;
			if (event.x() >= left() + 10 && event.x() <= left() + PANEL_WIDTH - 10 && event.y() >= listTop() && event.y() < listBottom()
				&& row >= 0 && row < ALTS.size()) {
				selected = row;
				if (doubleClick) {
					loginSelected();
				}
				return true;
			}
			return super.mouseClicked(event, doubleClick);
		}

		@Override
		public boolean mouseScrolled(double mouseX, double mouseY, double horizontal, double vertical) {
			scroll = Math.max(0, Math.min(Math.max(0, ALTS.size() - visibleRows()), scroll - (int) Math.signum(vertical)));
			return true;
		}

		@Override
		public void render(GuiGraphics graphics, int mouseX, int mouseY, float delta) {
			int x = left();
			graphics.fill(x, 8, x + PANEL_WIDTH, height - 4, 0xE6121218);
			graphics.fill(x, 8, x + PANEL_WIDTH, 9, 0xFF8B7CF6);
			super.render(graphics, mouseX, mouseY, delta);
			graphics.drawString(font, title, x + 10, 16, 0xFFFFFFFF);
			graphics.drawString(font, "Current: " + minecraft.getUser().getName(), x + 10, 30, 0xFFA0A0B4);
			int rows = visibleRows();
			for (int i = scroll; i < Math.min(ALTS.size(), scroll + rows); i++) {
				int y = listTop() + (i - scroll) * ROW;
				boolean hovered = mouseX >= x + 10 && mouseX <= x + PANEL_WIDTH - 10 && mouseY >= y && mouseY < y + ROW - 2;
				int background = i == selected ? 0x668B7CF6 : hovered ? 0x33FFFFFF : 0x1AFFFFFF;
				graphics.fill(x + 10, y, x + PANEL_WIDTH - 10, y + ROW - 2, background);
				boolean active = ALTS.get(i).equals(minecraft.getUser().getName());
				graphics.drawString(font, ALTS.get(i), x + 16, y + 3, active ? 0xFF3DD68C : 0xFFFFFFFF);
				if (active) {
					graphics.drawString(font, "active", x + PANEL_WIDTH - 16 - font.width("active"), y + 3, 0xFF3DD68C);
				}
			}
			if (ALTS.isEmpty()) {
				graphics.drawCenteredString(font, "Type a nickname and press Add", width / 2, listTop() + 4, 0xFF707080);
			}
			if (!status.isEmpty()) {
				graphics.drawCenteredString(font, status, width / 2, height - 92, 0xFFF5D244);
			}
		}

		@Override
		public void onClose() {
			minecraft.setScreen(parent);
		}
	}
}
