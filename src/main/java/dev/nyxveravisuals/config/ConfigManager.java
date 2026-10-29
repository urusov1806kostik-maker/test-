package dev.nyxveravisuals.config;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;
import java.util.function.LongSupplier;

import com.google.gson.JsonObject;

import dev.nyxveravisuals.core.Log;

/**
 * Loads and saves {@link ConfigDocument}s. Saving is debounced: {@link #markDirty} only schedules, the
 * client tick ({@link #tick}) snapshots due documents on the client thread and a single background thread
 * writes them atomically. Broken files are backed up and replaced by defaults instead of crashing.
 */
public final class ConfigManager {
	public static final long SAVE_DEBOUNCE_MILLIS = 1500;

	private final Path root;
	private final LongSupplier millis;
	private final ExecutorService io;
	private final Map<ConfigDocument, Slot> slots = new LinkedHashMap<>();
	private final List<String> problems = new ArrayList<>();
	private final List<Future<?>> pendingWrites = new ArrayList<>();

	private static final class Slot {
		final ConfigDocument document;
		Path path;
		boolean dirty;
		long dueAt;

		Slot(ConfigDocument document, Path path) {
			this.document = document;
			this.path = path;
		}
	}

	public ConfigManager(Path root) {
		this(root, System::currentTimeMillis);
	}

	public ConfigManager(Path root, LongSupplier millis) {
		this.root = Objects.requireNonNull(root);
		this.millis = millis;
		this.io = Executors.newSingleThreadExecutor(runnable -> {
			Thread thread = new Thread(runnable, "NyxveraVisuals Config IO");
			thread.setDaemon(true);
			return thread;
		});
	}

	public Path root() {
		return root;
	}

	public void register(ConfigDocument document) {
		register(document, root.resolve(document.fileName()));
	}

	void register(ConfigDocument document, Path path) {
		if (slots.putIfAbsent(document, new Slot(document, path)) != null) {
			throw new IllegalArgumentException("Document already registered: " + document.fileName());
		}
	}

	/** Points a document at a different file (profile switches); pending changes are flushed first. */
	void retarget(ConfigDocument document, Path path) {
		Slot slot = slot(document);
		if (slot.dirty) {
			writeSnapshot(slot);
		}
		slot.path = path;
	}

	Path pathOf(ConfigDocument document) {
		return slot(document).path;
	}

	private Slot slot(ConfigDocument document) {
		Slot slot = slots.get(document);
		if (slot == null) {
			throw new IllegalArgumentException("Unregistered document: " + document.fileName());
		}
		return slot;
	}

	public void loadAll() {
		for (Slot slot : slots.values()) {
			load(slot);
		}
	}

	public void load(ConfigDocument document) {
		load(slot(document));
	}

	private void load(Slot slot) {
		JsonObject json = read(slot.path, slot.document.migrator());
		if (json == null) {
			slot.document.loadDefaults();
			return;
		}
		try {
			slot.document.load(json);
		} catch (RuntimeException e) {
			Log.error("Failed to apply {}; using defaults", slot.path.getFileName(), e);
			reportProblem(slot.path.getFileName().toString());
			slot.document.loadDefaults();
		}
	}

	/** Reads, validates and migrates a file. Returns {@code null} when the caller should use defaults. */
	JsonObject read(Path path, Migrator migrator) {
		JsonFiles.ReadResult result = JsonFiles.read(path);
		if (result instanceof JsonFiles.ReadResult.Missing) {
			return null;
		}
		if (result instanceof JsonFiles.ReadResult.Corrupt corrupt) {
			Log.error("Config file {} is corrupted; loading defaults", path, corrupt.cause());
			try {
				Path backup = JsonFiles.backupCorrupt(path);
				Log.warn("Corrupted config backed up to {}", backup);
			} catch (IOException e) {
				Log.error("Could not back up corrupted config {}", path, e);
			}
			reportProblem(path.getFileName().toString());
			return null;
		}
		JsonObject json = ((JsonFiles.ReadResult.Ok) result).json();
		int version = Migrator.versionOf(json);
		if (version > Migrator.CURRENT_SCHEMA) {
			Log.warn("{} was written by a newer NyxveraVisuals (schema {}); unknown entries will be ignored", path.getFileName(), version);
		} else if (version < Migrator.CURRENT_SCHEMA) {
			try {
				JsonFiles.backupBeforeMigration(path, version);
			} catch (IOException e) {
				Log.warn("Could not back up {} before migration", path, e);
			}
			Log.info("Migrating {} from schema {} to {}", path.getFileName(), version, Migrator.CURRENT_SCHEMA);
		}
		return migrator.migrate(json);
	}

	private void reportProblem(String fileName) {
		synchronized (problems) {
			problems.add(fileName);
		}
	}

	/** Files that were reset because they were broken; consumed once to notify the user. */
	public List<String> drainProblems() {
		synchronized (problems) {
			List<String> copy = List.copyOf(problems);
			problems.clear();
			return copy;
		}
	}

	public void markDirty(ConfigDocument document) {
		Slot slot = slots.get(document);
		if (slot == null) {
			return;
		}
		slot.dirty = true;
		slot.dueAt = millis.getAsLong() + SAVE_DEBOUNCE_MILLIS;
	}

	/** Called every client tick; only compares timestamps unless a save is due. */
	public void tick() {
		long now = millis.getAsLong();
		for (Slot slot : slots.values()) {
			if (slot.dirty && now >= slot.dueAt) {
				writeSnapshot(slot);
			}
		}
	}

	/** Snapshots on the calling thread and queues the write. */
	public void saveNow(ConfigDocument document) {
		writeSnapshot(slot(document));
	}

	private void writeSnapshot(Slot slot) {
		slot.dirty = false;
		JsonObject snapshot;
		try {
			snapshot = slot.document.save();
		} catch (RuntimeException e) {
			Log.error("Failed to serialize {}", slot.path.getFileName(), e);
			return;
		}
		snapshot.addProperty(Migrator.SCHEMA_KEY, Migrator.CURRENT_SCHEMA);
		Path target = slot.path;
		synchronized (pendingWrites) {
			pendingWrites.removeIf(Future::isDone);
			pendingWrites.add(io.submit(() -> {
				try {
					JsonFiles.writeAtomic(target, snapshot);
					Log.debug("Saved {}", target.getFileName());
				} catch (IOException e) {
					Log.error("Failed to write config {}", target, e);
				}
			}));
		}
	}

	/** Saves every dirty document and waits for all queued writes. */
	public void flush() {
		for (Slot slot : slots.values()) {
			if (slot.dirty) {
				writeSnapshot(slot);
			}
		}
		awaitWrites();
	}

	void awaitWrites() {
		List<Future<?>> waiting;
		synchronized (pendingWrites) {
			waiting = new ArrayList<>(pendingWrites);
			pendingWrites.clear();
		}
		for (Future<?> future : waiting) {
			try {
				future.get(5, TimeUnit.SECONDS);
			} catch (InterruptedException e) {
				Thread.currentThread().interrupt();
				return;
			} catch (Exception e) {
				Log.error("Config write did not complete", e);
			}
		}
	}

	public void shutdown() {
		flush();
		io.shutdown();
		try {
			if (!io.awaitTermination(5, TimeUnit.SECONDS)) {
				Log.warn("Config IO thread did not stop in time");
			}
		} catch (InterruptedException e) {
			Thread.currentThread().interrupt();
		}
	}

	public void ensureRoot() {
		try {
			Files.createDirectories(root);
		} catch (IOException e) {
			Log.error("Could not create config directory {}", root, e);
		}
	}
}
