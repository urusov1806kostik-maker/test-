package dev.nyxveravisuals.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Stream;

import com.google.gson.JsonObject;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

class ConfigTest {
	@TempDir
	Path dir;

	static final class ValueDocument implements ConfigDocument {
		int value;
		int loads;
		final String name;

		ValueDocument(String name) {
			this.name = name;
		}

		@Override
		public String fileName() {
			return name;
		}

		@Override
		public JsonObject save() {
			JsonObject json = new JsonObject();
			json.addProperty("value", value);
			return json;
		}

		@Override
		public void load(JsonObject json) {
			loads++;
			value = json.has("value") ? json.get("value").getAsInt() : 0;
		}

		@Override
		public void loadDefaults() {
			loads++;
			value = 0;
		}
	}

	@Test
	void debouncedSaveWritesOnlyWhenDue() throws IOException {
		AtomicLong time = new AtomicLong(1000);
		ConfigManager config = new ConfigManager(dir, time::get);
		ValueDocument document = new ValueDocument("test.json");
		config.register(document);
		document.value = 5;
		config.markDirty(document);
		config.tick();
		config.awaitWrites();
		assertFalse(Files.exists(dir.resolve("test.json")));

		time.addAndGet(ConfigManager.SAVE_DEBOUNCE_MILLIS);
		config.tick();
		config.awaitWrites();
		String written = Files.readString(dir.resolve("test.json"));
		assertTrue(written.contains("\"value\": 5"));
		assertTrue(written.contains("\"schema\": " + Migrator.CURRENT_SCHEMA));
		config.shutdown();
	}

	@Test
	void corruptedFileIsBackedUpAndDefaultsLoaded() throws IOException {
		Files.writeString(dir.resolve("broken.json"), "{ this is not json");
		ConfigManager config = new ConfigManager(dir);
		ValueDocument document = new ValueDocument("broken.json");
		document.value = 99;
		config.register(document);
		config.loadAll();
		assertEquals(0, document.value);
		assertEquals(List.of("broken.json"), config.drainProblems());
		try (Stream<Path> files = Files.list(dir)) {
			assertTrue(files.anyMatch(path -> path.getFileName().toString().startsWith("broken.corrupt-")));
		}
		config.shutdown();
	}

	@Test
	void profilesLifecycle() {
		ConfigManager config = new ConfigManager(dir);
		ValueDocument content = new ValueDocument("profile");
		ProfileManager profiles = new ProfileManager(config, content);
		profiles.initialize("missing");
		assertEquals(ProfileManager.DEFAULT, profiles.active());

		content.value = 3;
		assertEquals(ProfileManager.Outcome.OK, profiles.create("PvP", false));
		assertEquals(ProfileManager.Outcome.ALREADY_EXISTS, profiles.create("pvp", false));
		assertEquals(ProfileManager.Outcome.INVALID_NAME, profiles.create("../evil", false));
		assertEquals(ProfileManager.Outcome.INVALID_NAME, profiles.create("con", false));

		content.value = 1;
		assertEquals(ProfileManager.Outcome.OK, profiles.load("PvP"));
		assertEquals(3, content.value);

		assertEquals(ProfileManager.Outcome.OK, profiles.duplicate("PvP", "Copy"));
		assertEquals(ProfileManager.Outcome.OK, profiles.rename("PvP", "Arena"));
		assertEquals("Arena", profiles.active());
		assertEquals(ProfileManager.Outcome.PROTECTED, profiles.delete(ProfileManager.DEFAULT));

		assertEquals(ProfileManager.Outcome.OK, profiles.delete("Arena"));
		assertEquals(ProfileManager.DEFAULT, profiles.active());
		assertEquals(1, content.value);
		assertEquals(List.of("default", "Copy"), profiles.list());
		config.shutdown();
	}

	@Test
	void migratorRunsStepsAndStampsVersion() {
		JsonObject json = new JsonObject();
		json.addProperty(Migrator.SCHEMA_KEY, 0);
		JsonObject migrated = Migrator.NONE.migrate(json);
		assertEquals(Migrator.CURRENT_SCHEMA, Migrator.versionOf(migrated));
	}
}
