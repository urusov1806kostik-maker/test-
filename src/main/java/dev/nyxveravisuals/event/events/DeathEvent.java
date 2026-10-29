package dev.nyxveravisuals.event.events;

/** The local player died at the given block position and dimension. */
public record DeathEvent(int x, int y, int z, String dimension) {
}
