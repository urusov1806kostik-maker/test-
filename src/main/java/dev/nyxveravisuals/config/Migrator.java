package dev.nyxveravisuals.config;

import java.util.Map;
import java.util.TreeMap;
import java.util.function.UnaryOperator;

import com.google.gson.JsonObject;

/**
 * Upgrades JSON documents step by step from their stored schema version to {@link #CURRENT_SCHEMA}.
 * Each step transforms version {@code n} into {@code n + 1}.
 */
public final class Migrator {
	/** Bump when the persisted structure changes and register a step for the previous version. */
	public static final int CURRENT_SCHEMA = 1;
	public static final String SCHEMA_KEY = "schema";
	public static final Migrator NONE = new Migrator();

	private final Map<Integer, UnaryOperator<JsonObject>> steps = new TreeMap<>();

	public Migrator step(int fromVersion, UnaryOperator<JsonObject> transform) {
		if (fromVersion >= CURRENT_SCHEMA) {
			throw new IllegalArgumentException("Migration step must start below the current schema");
		}
		steps.put(fromVersion, transform);
		return this;
	}

	public static int versionOf(JsonObject json) {
		if (json.has(SCHEMA_KEY) && json.get(SCHEMA_KEY).isJsonPrimitive()) {
			try {
				return json.get(SCHEMA_KEY).getAsInt();
			} catch (NumberFormatException e) {
				return CURRENT_SCHEMA;
			}
		}
		return CURRENT_SCHEMA;
	}

	/** Returns the migrated document (the input may be mutated). Unknown future versions are left as-is. */
	public JsonObject migrate(JsonObject json) {
		int version = versionOf(json);
		JsonObject current = json;
		while (version < CURRENT_SCHEMA) {
			UnaryOperator<JsonObject> step = steps.get(version);
			if (step != null) {
				current = step.apply(current);
			}
			version++;
		}
		current.addProperty(SCHEMA_KEY, Math.max(version, CURRENT_SCHEMA));
		return current;
	}
}
