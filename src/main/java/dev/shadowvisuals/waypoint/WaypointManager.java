package dev.shadowvisuals.waypoint;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import java.util.UUID;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;

import dev.shadowvisuals.config.ConfigDocument;
import dev.shadowvisuals.core.Log;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Stores waypoints for all worlds and serves the ones of the current world/dimension from a cached list
 * (rebuilt only on change), so rendering never allocates. Death points are capped per world.
 */
public final class WaypointManager implements ConfigDocument {
	public static final int MAX_WAYPOINTS = 512;

	private final List<Waypoint> waypoints = new ArrayList<>();
	private Runnable dirtyHook = () -> { };
	private String cachedWorld;
	private String cachedDimension;
	private List<Waypoint> cachedVisible = List.of();
	private int revision;

	public void setDirtyHook(Runnable hook) {
		this.dirtyHook = Objects.requireNonNull(hook);
	}

	public int revision() {
		return revision;
	}

	public List<Waypoint> all() {
		return List.copyOf(waypoints);
	}

	public List<Waypoint> inWorld(String world) {
		List<Waypoint> result = new ArrayList<>();
		for (Waypoint waypoint : waypoints) {
			if (waypoint.world().equals(world)) {
				result.add(waypoint);
			}
		}
		return result;
	}

	/** Visible waypoints of the given world and dimension; cached until the next change. */
	public List<Waypoint> visibleIn(String world, String dimension) {
		if (!Objects.equals(world, cachedWorld) || !Objects.equals(dimension, cachedDimension)) {
			cachedWorld = world;
			cachedDimension = dimension;
			rebuildCache();
		}
		return cachedVisible;
	}

	private void rebuildCache() {
		List<Waypoint> result = new ArrayList<>();
		for (Waypoint waypoint : waypoints) {
			if (waypoint.visible() && waypoint.world().equals(cachedWorld) && waypoint.dimension().equals(cachedDimension)) {
				result.add(waypoint);
			}
		}
		cachedVisible = List.copyOf(result);
	}

	private void changed() {
		revision++;
		rebuildCache();
		dirtyHook.run();
	}

	public boolean add(Waypoint waypoint) {
		if (waypoints.size() >= MAX_WAYPOINTS) {
			Log.warn("Waypoint limit ({}) reached; not adding {}", MAX_WAYPOINTS, waypoint.name());
			return false;
		}
		waypoints.add(waypoint);
		changed();
		return true;
	}

	public Waypoint create(String name, int x, int y, int z, String dimension, String world, int color) {
		Waypoint waypoint = new Waypoint(UUID.randomUUID(), name, x, y, z, dimension, world, color, true,
			Waypoint.Kind.MANUAL, System.currentTimeMillis());
		return add(waypoint) ? waypoint : null;
	}

	public boolean update(Waypoint updated) {
		for (int i = 0; i < waypoints.size(); i++) {
			if (waypoints.get(i).id().equals(updated.id())) {
				waypoints.set(i, updated);
				changed();
				return true;
			}
		}
		return false;
	}

	public boolean remove(UUID id) {
		if (waypoints.removeIf(waypoint -> waypoint.id().equals(id))) {
			changed();
			return true;
		}
		return false;
	}

	/** Records a death point, keeping at most {@code keep} death points per world (oldest removed). */
	public Waypoint addDeathPoint(String name, int x, int y, int z, String dimension, String world, int color, int keep) {
		List<Waypoint> deaths = new ArrayList<>();
		for (Waypoint waypoint : waypoints) {
			if (waypoint.kind() == Waypoint.Kind.DEATH && waypoint.world().equals(world)) {
				deaths.add(waypoint);
			}
		}
		deaths.sort(Comparator.comparingLong(Waypoint::createdAt));
		int limit = Math.max(1, keep);
		for (int i = 0; i <= deaths.size() - limit; i++) {
			UUID id = deaths.get(i).id();
			waypoints.removeIf(waypoint -> waypoint.id().equals(id));
		}
		Waypoint death = new Waypoint(UUID.randomUUID(), name, x, y, z, dimension, world, color, true,
			Waypoint.Kind.DEATH, System.currentTimeMillis());
		waypoints.add(death);
		changed();
		return death;
	}

	public void clearDeathPoints(String world) {
		if (waypoints.removeIf(waypoint -> waypoint.kind() == Waypoint.Kind.DEATH && waypoint.world().equals(world))) {
			changed();
		}
	}

	@Override
	public String fileName() {
		return "waypoints.json";
	}

	@Override
	public JsonObject save() {
		JsonArray array = new JsonArray();
		for (Waypoint waypoint : waypoints) {
			JsonObject entry = new JsonObject();
			entry.addProperty("id", waypoint.id().toString());
			entry.addProperty("name", waypoint.name());
			entry.addProperty("x", waypoint.x());
			entry.addProperty("y", waypoint.y());
			entry.addProperty("z", waypoint.z());
			entry.addProperty("dimension", waypoint.dimension());
			entry.addProperty("world", waypoint.world());
			entry.addProperty("color", ColorUtil.toHex(waypoint.color(), true));
			entry.addProperty("visible", waypoint.visible());
			entry.addProperty("kind", waypoint.kind().name());
			entry.addProperty("created", waypoint.createdAt());
			array.add(entry);
		}
		JsonObject json = new JsonObject();
		json.add("waypoints", array);
		return json;
	}

	@Override
	public void load(JsonObject json) {
		waypoints.clear();
		if (json.has("waypoints") && json.get("waypoints").isJsonArray()) {
			for (JsonElement element : json.getAsJsonArray("waypoints")) {
				Waypoint waypoint = parse(element);
				if (waypoint != null && waypoints.size() < MAX_WAYPOINTS) {
					waypoints.add(waypoint);
				}
			}
		}
		revision++;
		rebuildCache();
	}

	private static Waypoint parse(JsonElement element) {
		if (!element.isJsonObject()) {
			return null;
		}
		try {
			JsonObject entry = element.getAsJsonObject();
			Integer color = ColorUtil.parseHex(entry.get("color").getAsString());
			Waypoint.Kind kind = Waypoint.Kind.MANUAL;
			if (entry.has("kind")) {
				for (Waypoint.Kind candidate : Waypoint.Kind.values()) {
					if (candidate.name().equalsIgnoreCase(entry.get("kind").getAsString())) {
						kind = candidate;
					}
				}
			}
			return new Waypoint(
				UUID.fromString(entry.get("id").getAsString()),
				entry.get("name").getAsString(),
				entry.get("x").getAsInt(),
				entry.get("y").getAsInt(),
				entry.get("z").getAsInt(),
				entry.get("dimension").getAsString(),
				entry.get("world").getAsString(),
				color == null ? 0xFF8B7CF6 : color,
				!entry.has("visible") || entry.get("visible").getAsBoolean(),
				kind,
				entry.has("created") ? entry.get("created").getAsLong() : 0L);
		} catch (RuntimeException e) {
			Log.warn("Skipping invalid waypoint entry: {}", element);
			return null;
		}
	}

	@Override
	public void loadDefaults() {
		waypoints.clear();
		revision++;
		rebuildCache();
	}
}
