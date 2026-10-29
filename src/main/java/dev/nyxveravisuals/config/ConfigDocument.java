package dev.nyxveravisuals.config;

import com.google.gson.JsonObject;

/** One persisted JSON file. Implementations snapshot state on the client thread; IO happens elsewhere. */
public interface ConfigDocument {
	/** File name relative to the client config directory, e.g. {@code friends.json}. */
	String fileName();

	JsonObject save();

	void load(JsonObject json);

	void loadDefaults();

	/** Migrations for this document's schema; empty by default. */
	default Migrator migrator() {
		return Migrator.NONE;
	}
}
