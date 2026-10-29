package dev.nyxveravisuals.modules.utility;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Pattern;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.google.gson.JsonParser;

import net.minecraft.client.Minecraft;
import net.minecraft.client.User;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.Button;
import net.minecraft.client.gui.components.EditBox;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.gui.screens.TitleScreen;
import net.minecraft.client.gui.screens.multiplayer.JoinMultiplayerScreen;
import net.minecraft.core.UUIDUtil;
import net.minecraft.network.chat.Component;

import net.fabricmc.fabric.api.client.screen.v1.ScreenEvents;
import net.fabricmc.fabric.api.client.screen.v1.Screens;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.config.JsonFiles;
import dev.nyxveravisuals.core.Log;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.ActionSetting;

/**
 * Offline (no-password) account switcher for servers that accept any nickname. Keeps a list of nicknames in
 * {@code config/nyxveravisuals/alts.json}, switches the session to the chosen one and can restore the account
 * the game was started with. Microsoft passwords and tokens are never asked for or stored. Switching is only
 * possible outside a world; an "Alts" button is added to the title and multiplayer screens.
 */
public final class AltManager extends Module {
	private static final Pattern VALID_NAME = Pattern.compile("[A-Za-z0-9_]{3,16}");
	private static final int MAX_ALTS = 100;

	private final NyxveraClient client;
	private final List<String> alts = new ArrayList<>();
	private User original;
	private boolean loaded;

	public AltManager(NyxveraClient client) {
		super("alt_manager", Category.UTILITY);
		this.client = client;
		settings().add(new ActionSetting("open_alt_manager", this::open));
		ScreenEvents.AFTER_INIT.register((minecraft, screen, width, height) -> {
			if (screen instanceof TitleScreen || screen instanceof JoinMultiplayerScreen) {
				Screens.getButtons(screen).add(Button.builder(Component.literal("Alts"), button -> minecraft.setScreen(new AltScreen(screen)))
					.bounds(width - 54, 4, 50, 20).build());
			}
		});
	}

	@Override
	public boolean isToggleable() {
		return false;
	}

	private void open() {
		Minecraft minecraft = Minecraft.getInstance();
		minecraft.setScreen(new AltScreen(minecraft.screen));
	}

	private Path file() {
		return client.config().root().resolve("alts.json");
	}

	private void load() {
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
					if (VALID_NAME.matcher(name).matches() && !alts.contains(name) && alts.size() < MAX_ALTS) {
						alts.add(name);
					}
				}
			}
		} catch (IOException | JsonParseException | IllegalStateException | UnsupportedOperationException e) {
			Log.warn("Could not read {}: {}", file, e.toString());
		}
	}

	private void save() {
		JsonObject json = new JsonObject();
		JsonArray list = new JsonArray();
		alts.forEach(list::add);
		json.add("alts", list);
		try {
			Files.createDirectories(file().getParent());
			JsonFiles.writeAtomic(file(), json);
		} catch (IOException e) {
			Log.warn("Could not save {}: {}", file(), e.toString());
		}
	}

	/** Switches the session to the offline account {@code name}; returns false when not allowed right now. */
	private boolean login(String name) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.level != null || !VALID_NAME.matcher(name).matches()) {
			return false;
		}
		if (original == null) {
			original = minecraft.getUser();
		}
		minecraft.user = new User(name, UUIDUtil.createOfflinePlayerUUID(name), "", Optional.empty(), Optional.empty());
		return true;
	}

	private void restore() {
		Minecraft minecraft = Minecraft.getInstance();
		if (original != null && minecraft.level == null) {
			minecraft.user = original;
			original = null;
		}
	}

	/** List of nicknames with add, log in, remove and restore. */
	private final class AltScreen extends Screen {
		private final Screen parent;
		private EditBox input;
		private String status = "";
		private int selected = -1;
		private int scroll;

		AltScreen(Screen parent) {
			super(Component.literal("Alt Manager"));
			this.parent = parent;
		}

		@Override
		protected void init() {
			load();
			int center = width / 2;
			input = new EditBox(font, center - 100, height - 76, 200, 20, Component.literal("Nickname"));
			input.setMaxLength(16);
			input.setHint(Component.literal("Nickname (3-16: A-Z 0-9 _)"));
			addRenderableWidget(input);
			addRenderableWidget(Button.builder(Component.literal("Add"), button -> add()).bounds(center - 100, height - 52, 64, 20).build());
			addRenderableWidget(Button.builder(Component.literal("Log in"), button -> loginSelected()).bounds(center - 32, height - 52, 64, 20).build());
			addRenderableWidget(Button.builder(Component.literal("Remove"), button -> remove()).bounds(center + 36, height - 52, 64, 20).build());
			addRenderableWidget(Button.builder(Component.literal("Original account"), button -> {
				restore();
				status = "Logged in as " + minecraft.getUser().getName();
			}).bounds(center - 100, height - 28, 98, 20).build());
			addRenderableWidget(Button.builder(Component.literal("Done"), button -> onClose()).bounds(center + 2, height - 28, 98, 20).build());
			setInitialFocus(input);
		}

		private void add() {
			String name = input.getValue().strip();
			if (!VALID_NAME.matcher(name).matches()) {
				status = "Invalid nickname";
			} else if (alts.contains(name)) {
				status = "Already in the list";
			} else if (alts.size() >= MAX_ALTS) {
				status = "List is full";
			} else {
				alts.add(name);
				selected = alts.size() - 1;
				input.setValue("");
				save();
				status = "Added " + name;
			}
		}

		private void loginSelected() {
			String name = selected >= 0 && selected < alts.size() ? alts.get(selected) : input.getValue().strip();
			if (minecraft.level != null) {
				status = "Leave the world first";
			} else if (login(name)) {
				status = "Logged in as " + name;
			} else {
				status = "Select or type a valid nickname";
			}
		}

		private void remove() {
			if (selected >= 0 && selected < alts.size()) {
				status = "Removed " + alts.remove(selected);
				selected = -1;
				save();
			}
		}

		private int rowTop() {
			return 40;
		}

		private int visibleRows() {
			return Math.max(1, (height - 84 - rowTop()) / 14);
		}

		@Override
		public boolean mouseClicked(net.minecraft.client.input.MouseButtonEvent event, boolean doubleClick) {
			int row = (int) ((event.y() - rowTop()) / 14) + scroll;
			if (event.y() >= rowTop() && row >= 0 && row < alts.size() && row < scroll + visibleRows()
				&& Math.abs(event.x() - width / 2.0) <= 100) {
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
			scroll = Math.max(0, Math.min(Math.max(0, alts.size() - visibleRows()), scroll - (int) Math.signum(vertical)));
			return true;
		}

		@Override
		public void render(GuiGraphics graphics, int mouseX, int mouseY, float delta) {
			super.render(graphics, mouseX, mouseY, delta);
			int center = width / 2;
			graphics.drawCenteredString(font, title, center, 10, 0xFFFFFFFF);
			graphics.drawCenteredString(font, "Current: " + minecraft.getUser().getName(), center, 24, 0xFFB0B0C0);
			int rows = visibleRows();
			for (int i = scroll; i < Math.min(alts.size(), scroll + rows); i++) {
				int y = rowTop() + (i - scroll) * 14;
				boolean active = alts.get(i).equals(minecraft.getUser().getName());
				graphics.fill(center - 100, y, center + 100, y + 13, i == selected ? 0x668B7CF6 : 0x33000000);
				graphics.drawString(font, alts.get(i), center - 94, y + 3, active ? 0xFF3DD68C : 0xFFFFFFFF);
			}
			if (alts.isEmpty()) {
				graphics.drawCenteredString(font, "No alts yet: type a nickname and press Add", center, rowTop() + 4, 0xFF808090);
			}
			if (!status.isEmpty()) {
				graphics.drawCenteredString(font, status, center, height - 90, 0xFFF5D244);
			}
		}

		@Override
		public void onClose() {
			minecraft.setScreen(parent);
		}
	}
}
