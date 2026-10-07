package dev.shadowvisuals.waypoint;

import java.util.UUID;

/**
 * Immutable waypoint. {@code world} identifies the server or singleplayer save, {@code dimension} the
 * dimension id (e.g. {@code minecraft:the_nether}), so points never leak between worlds.
 */
public record Waypoint(UUID id, String name, int x, int y, int z, String dimension, String world,
	int color, boolean visible, Kind kind, long createdAt) {
	public enum Kind {
		MANUAL,
		DEATH
	}

	public static final int MAX_NAME_LENGTH = 32;

	public Waypoint {
		if (name == null || name.isBlank()) {
			name = "Waypoint";
		} else if (name.length() > MAX_NAME_LENGTH) {
			name = name.substring(0, MAX_NAME_LENGTH);
		}
	}

	public Waypoint withName(String value) {
		return new Waypoint(id, value, x, y, z, dimension, world, color, visible, kind, createdAt);
	}

	public Waypoint withColor(int value) {
		return new Waypoint(id, name, x, y, z, dimension, world, value, visible, kind, createdAt);
	}

	public Waypoint withVisible(boolean value) {
		return new Waypoint(id, name, x, y, z, dimension, world, color, value, kind, createdAt);
	}

	public Waypoint withPosition(int newX, int newY, int newZ) {
		return new Waypoint(id, name, newX, newY, newZ, dimension, world, color, visible, kind, createdAt);
	}

	public double distanceTo(double px, double py, double pz) {
		double dx = x + 0.5 - px;
		double dy = y + 0.5 - py;
		double dz = z + 0.5 - pz;
		return Math.sqrt(dx * dx + dy * dy + dz * dz);
	}
}
