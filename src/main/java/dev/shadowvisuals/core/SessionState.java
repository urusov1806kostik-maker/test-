package dev.shadowvisuals.core;

import java.util.Locale;

import net.minecraft.client.Minecraft;
import net.minecraft.client.multiplayer.ServerData;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.client.server.IntegratedServer;

/**
 * Tracks the current play session (world identity, dimension, local player instance, death state) and turns
 * changes into lifecycle callbacks. Everything here tolerates a missing player or world.
 */
public final class SessionState {
	public interface Listener {
		void onDimensionChanged(String from, String to);

		void onRespawn();

		void onDeath(int x, int y, int z, String dimension);
	}

	private String worldKey = "";
	private String dimension = "";
	private LocalPlayer trackedPlayer;
	private boolean dead;
	private long joinedAtMillis;
	private boolean inWorld;

	public void onJoin(Minecraft client) {
		inWorld = true;
		joinedAtMillis = System.currentTimeMillis();
		worldKey = computeWorldKey(client);
		dimension = client.level != null ? client.level.dimension().identifier().toString() : "";
		trackedPlayer = client.player;
		dead = false;
	}

	public void onLeave() {
		inWorld = false;
		worldKey = "";
		dimension = "";
		trackedPlayer = null;
		dead = false;
	}

	/** Called every client tick; detects dimension changes, respawns and deaths without mixins. */
	public void tick(Minecraft client, Listener listener) {
		if (!inWorld || client.level == null) {
			return;
		}
		String currentDimension = client.level.dimension().identifier().toString();
		if (!currentDimension.equals(dimension)) {
			String previous = dimension;
			dimension = currentDimension;
			if (!previous.isEmpty()) {
				listener.onDimensionChanged(previous, currentDimension);
			}
		}
		LocalPlayer player = client.player;
		if (player == null) {
			return;
		}
		if (player != trackedPlayer) {
			boolean replaced = trackedPlayer != null;
			trackedPlayer = player;
			dead = false;
			if (replaced) {
				listener.onRespawn();
			}
		}
		boolean nowDead = player.isDeadOrDying();
		if (nowDead && !dead) {
			listener.onDeath(player.getBlockX(), player.getBlockY(), player.getBlockZ(), currentDimension);
		}
		dead = nowDead;
	}

	private static String computeWorldKey(Minecraft client) {
		IntegratedServer integrated = client.getSingleplayerServer();
		if (integrated != null) {
			return "sp:" + integrated.getWorldData().getLevelName();
		}
		ServerData server = client.getCurrentServer();
		if (server != null) {
			return "mp:" + server.ip.toLowerCase(Locale.ROOT);
		}
		return "unknown";
	}

	public boolean inWorld() {
		return inWorld;
	}

	public String worldKey() {
		return worldKey;
	}

	public String dimension() {
		return dimension;
	}

	public long sessionMillis() {
		return inWorld ? System.currentTimeMillis() - joinedAtMillis : 0L;
	}

	/** Server address for display, or {@code null} in singleplayer. */
	public String serverAddress(Minecraft client) {
		ServerData server = client.getCurrentServer();
		return server != null && client.getSingleplayerServer() == null ? server.ip : null;
	}
}
