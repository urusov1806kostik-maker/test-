package dev.shadowvisuals.config;

import java.io.IOException;
import java.nio.file.DirectoryStream;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;

import com.google.gson.JsonObject;

import dev.shadowvisuals.core.Log;

/**
 * Named profiles under {@code profiles/}. The profile document (modules, HUD, theme) is a single
 * {@link ConfigDocument} that is retargeted at the selected file. The {@value #DEFAULT} profile always
 * exists and cannot be deleted or renamed.
 */
public final class ProfileManager {
	public static final String DEFAULT = "default";
	public static final int MAX_NAME_LENGTH = 32;
	private static final Set<String> RESERVED = Set.of("con", "prn", "aux", "nul",
		"com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9",
		"lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9");

	public enum Outcome {
		OK,
		INVALID_NAME,
		ALREADY_EXISTS,
		NOT_FOUND,
		PROTECTED,
		IO_ERROR
	}

	private final ConfigManager config;
	private final ConfigDocument content;
	private final Path directory;
	private final List<Runnable> listeners = new ArrayList<>();
	private String active = DEFAULT;

	public ProfileManager(ConfigManager config, ConfigDocument content) {
		this.config = Objects.requireNonNull(config);
		this.content = Objects.requireNonNull(content);
		this.directory = config.root().resolve("profiles");
		config.register(content, file(DEFAULT));
	}

	public ConfigDocument content() {
		return content;
	}

	public String active() {
		return active;
	}

	public void addListener(Runnable listener) {
		listeners.add(listener);
	}

	private void fireChanged() {
		for (Runnable listener : listeners) {
			listener.run();
		}
	}

	private Path file(String name) {
		return directory.resolve(name + ".json");
	}

	public static boolean isValidName(String name) {
		if (name == null || name.isBlank() || name.length() > MAX_NAME_LENGTH || !name.equals(name.strip())) {
			return false;
		}
		if (name.startsWith(".") || name.endsWith(".") || RESERVED.contains(name.toLowerCase(Locale.ROOT))) {
			return false;
		}
		for (int i = 0; i < name.length(); i++) {
			char c = name.charAt(i);
			if (!Character.isLetterOrDigit(c) && c != ' ' && c != '_' && c != '-' && c != '.') {
				return false;
			}
		}
		return !name.contains(".corrupt-") && !name.contains(".bak") && !name.endsWith(".tmp");
	}

	public boolean exists(String name) {
		return isValidName(name) && Files.isRegularFile(file(name));
	}

	/** Case-insensitive, so profiles behave the same on Windows and Linux file systems. */
	private boolean nameTaken(String name) {
		for (String existing : list()) {
			if (existing.equalsIgnoreCase(name)) {
				return true;
			}
		}
		return false;
	}

	/** Profile names sorted with {@value #DEFAULT} first. */
	public List<String> list() {
		List<String> names = new ArrayList<>();
		names.add(DEFAULT);
		if (!Files.isDirectory(directory)) {
			return names;
		}
		try (DirectoryStream<Path> stream = Files.newDirectoryStream(directory, "*.json")) {
			for (Path path : stream) {
				String fileName = path.getFileName().toString();
				String name = fileName.substring(0, fileName.length() - 5);
				if (!name.equals(DEFAULT) && isValidName(name)) {
					names.add(name);
				}
			}
		} catch (IOException e) {
			Log.error("Could not list profiles in {}", directory, e);
		}
		names.subList(1, names.size()).sort(String.CASE_INSENSITIVE_ORDER);
		return names;
	}

	/** Initial selection at startup: loads {@code name}, falling back to the default profile. */
	public void initialize(String name) {
		String target = name != null && exists(name) ? name : DEFAULT;
		active = target;
		config.retarget(content, file(target));
		config.load(content);
	}

	/** Saves the current profile, then switches to {@code name}. */
	public Outcome load(String name) {
		if (!isValidName(name)) {
			return Outcome.INVALID_NAME;
		}
		if (!name.equals(DEFAULT) && !exists(name)) {
			return Outcome.NOT_FOUND;
		}
		config.saveNow(content);
		config.awaitWrites();
		active = name;
		config.retarget(content, file(name));
		config.load(content);
		fireChanged();
		return Outcome.OK;
	}

	public void save() {
		config.saveNow(content);
	}

	/** Creates a profile either from the current state or from defaults. Does not switch to it. */
	public Outcome create(String name, boolean fromDefaults) {
		if (!isValidName(name)) {
			return Outcome.INVALID_NAME;
		}
		if (nameTaken(name)) {
			return Outcome.ALREADY_EXISTS;
		}
		JsonObject json = fromDefaults ? new JsonObject() : content.save();
		json.addProperty(Migrator.SCHEMA_KEY, Migrator.CURRENT_SCHEMA);
		try {
			JsonFiles.writeAtomic(file(name), json);
		} catch (IOException e) {
			Log.error("Could not create profile {}", name, e);
			return Outcome.IO_ERROR;
		}
		fireChanged();
		return Outcome.OK;
	}

	public Outcome duplicate(String source, String target) {
		if (!isValidName(source) || !isValidName(target)) {
			return Outcome.INVALID_NAME;
		}
		if (nameTaken(target)) {
			return Outcome.ALREADY_EXISTS;
		}
		if (source.equals(active)) {
			config.saveNow(content);
		}
		config.awaitWrites();
		try {
			Files.createDirectories(directory);
			if (Files.isRegularFile(file(source))) {
				Files.copy(file(source), file(target));
			} else if (source.equals(DEFAULT)) {
				JsonObject json = new JsonObject();
				json.addProperty(Migrator.SCHEMA_KEY, Migrator.CURRENT_SCHEMA);
				JsonFiles.writeAtomic(file(target), json);
			} else {
				return Outcome.NOT_FOUND;
			}
		} catch (IOException e) {
			Log.error("Could not duplicate profile {} to {}", source, target, e);
			return Outcome.IO_ERROR;
		}
		fireChanged();
		return Outcome.OK;
	}

	public Outcome rename(String from, String to) {
		if (!isValidName(from) || !isValidName(to)) {
			return Outcome.INVALID_NAME;
		}
		if (from.equals(DEFAULT)) {
			return Outcome.PROTECTED;
		}
		if (!exists(from)) {
			return Outcome.NOT_FOUND;
		}
		if (!to.equalsIgnoreCase(from) && nameTaken(to)) {
			return Outcome.ALREADY_EXISTS;
		}
		boolean renamingActive = from.equals(active);
		if (renamingActive) {
			config.saveNow(content);
		}
		config.awaitWrites();
		try {
			if (to.equalsIgnoreCase(from)) {
				// Case-only rename: go through a temporary name for case-insensitive file systems.
				Path temp = directory.resolve(from + ".rename.tmp");
				Files.move(file(from), temp);
				Files.move(temp, file(to));
			} else {
				Files.move(file(from), file(to));
			}
		} catch (IOException e) {
			Log.error("Could not rename profile {} to {}", from, to, e);
			return Outcome.IO_ERROR;
		}
		if (renamingActive) {
			active = to;
			config.retarget(content, file(to));
		}
		fireChanged();
		return Outcome.OK;
	}

	/** Deletes a profile; deleting the active one switches to the default profile first. */
	public Outcome delete(String name) {
		if (!isValidName(name)) {
			return Outcome.INVALID_NAME;
		}
		if (name.equals(DEFAULT)) {
			return Outcome.PROTECTED;
		}
		if (!exists(name)) {
			return Outcome.NOT_FOUND;
		}
		if (name.equals(active)) {
			load(DEFAULT);
		}
		config.awaitWrites();
		try {
			Files.deleteIfExists(file(name));
		} catch (IOException e) {
			Log.error("Could not delete profile {}", name, e);
			return Outcome.IO_ERROR;
		}
		fireChanged();
		return Outcome.OK;
	}
}
