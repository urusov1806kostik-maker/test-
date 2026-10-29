package dev.nyxveravisuals.media;

import java.util.Locale;

/**
 * Snapshot of the system's current media session. Position is the value reported by the player at
 * {@code positionSampledAt} (epoch millis); {@link #positionAt(long)} extrapolates it while playing, because
 * players only report position on changes.
 */
public record MediaInfo(String title, String artist, String album, String sourceApp, boolean playing,
	long positionMillis, long durationMillis, long positionSampledAt) {

	public MediaInfo {
		title = title == null ? "" : title.strip();
		artist = artist == null ? "" : artist.strip();
		album = album == null ? "" : album.strip();
		sourceApp = sourceApp == null ? "" : sourceApp;
	}

	public boolean hasTrack() {
		return !title.isEmpty();
	}

	/** Identity of the track independent of playback state: artist and title, case-insensitive. */
	public String trackKey() {
		return (artist + "\u0000" + title).toLowerCase(Locale.ROOT);
	}

	/** Playback position now, clamped to the track length when it is known. */
	public long positionAt(long nowMillis) {
		long position = positionMillis;
		if (playing && positionSampledAt > 0) {
			position += Math.max(0, nowMillis - positionSampledAt);
		}
		return durationMillis > 0 ? Math.min(position, durationMillis) : position;
	}
}
