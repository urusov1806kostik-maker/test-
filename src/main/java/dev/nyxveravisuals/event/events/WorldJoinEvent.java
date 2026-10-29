package dev.nyxveravisuals.event.events;

/** The client joined a world or server. {@code worldKey} identifies it for per-world data (waypoints). */
public record WorldJoinEvent(String worldKey) {
}
