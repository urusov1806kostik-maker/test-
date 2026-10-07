package dev.shadowvisuals.event.events;

/** The client level changed dimension (ids such as {@code minecraft:the_nether}). */
public record DimensionChangeEvent(String from, String to) {
}
