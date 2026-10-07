package dev.shadowvisuals.config;

import java.io.IOException;
import java.io.Reader;
import java.io.Writer;
import java.nio.charset.StandardCharsets;
import java.nio.file.AtomicMoveNotSupportedException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.google.gson.JsonParser;

/** Safe JSON file IO: tolerant reads, corrupted-file backups and atomic writes. */
public final class JsonFiles {
	public static final Gson GSON = new GsonBuilder().setPrettyPrinting().disableHtmlEscaping().create();
	private static final DateTimeFormatter BACKUP_STAMP = DateTimeFormatter.ofPattern("yyyyMMdd-HHmmss");

	public sealed interface ReadResult {
		record Ok(JsonObject json) implements ReadResult {
		}

		record Missing() implements ReadResult {
		}

		record Corrupt(Exception cause) implements ReadResult {
		}
	}

	private JsonFiles() {
	}

	public static ReadResult read(Path file) {
		if (!Files.isRegularFile(file)) {
			return new ReadResult.Missing();
		}
		try (Reader reader = Files.newBufferedReader(file, StandardCharsets.UTF_8)) {
			JsonElement element = JsonParser.parseReader(reader);
			if (!element.isJsonObject()) {
				return new ReadResult.Corrupt(new JsonParseException("Root element is not an object"));
			}
			return new ReadResult.Ok(element.getAsJsonObject());
		} catch (IOException | JsonParseException | IllegalStateException e) {
			return new ReadResult.Corrupt(e);
		}
	}

	/** Moves a broken file aside as {@code name.corrupt-<timestamp>.json} and returns the backup path. */
	public static Path backupCorrupt(Path file) throws IOException {
		String name = file.getFileName().toString();
		String base = name.endsWith(".json") ? name.substring(0, name.length() - 5) : name;
		Path backup = file.resolveSibling(base + ".corrupt-" + LocalDateTime.now().format(BACKUP_STAMP) + ".json");
		return Files.move(file, backup, StandardCopyOption.REPLACE_EXISTING);
	}

	/** Copies a file before it is rewritten by a migration (kept as {@code name.v<version>.bak.json}). */
	public static void backupBeforeMigration(Path file, int fromVersion) throws IOException {
		String name = file.getFileName().toString();
		String base = name.endsWith(".json") ? name.substring(0, name.length() - 5) : name;
		Files.copy(file, file.resolveSibling(base + ".v" + fromVersion + ".bak.json"), StandardCopyOption.REPLACE_EXISTING);
	}

	/** Writes through a temporary file and an atomic rename, so a crash never leaves a half-written config. */
	public static void writeAtomic(Path file, JsonObject json) throws IOException {
		Files.createDirectories(file.getParent());
		Path temp = file.resolveSibling(file.getFileName() + ".tmp");
		try (Writer writer = Files.newBufferedWriter(temp, StandardCharsets.UTF_8)) {
			GSON.toJson(json, writer);
		}
		try {
			Files.move(temp, file, StandardCopyOption.REPLACE_EXISTING, StandardCopyOption.ATOMIC_MOVE);
		} catch (AtomicMoveNotSupportedException e) {
			Files.move(temp, file, StandardCopyOption.REPLACE_EXISTING);
		}
	}
}
