package dev.shadowvisuals.core;

/**
 * Single source of truth for client identity. The version is injected once at bootstrap from the
 * Fabric metadata (which Gradle fills from {@code mod_version}), so it is never duplicated in code.
 */
public final class ClientInfo {
	public static final String MOD_ID = "shadowvisuals";
	public static final String NAME = "Shadow Visuals";

	private static String version = "dev";

	private ClientInfo() {
	}

	public static String version() {
		return version;
	}

	public static void setVersion(String value) {
		if (value != null && !value.isBlank()) {
			version = value;
		}
	}
}
