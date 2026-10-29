package dev.nyxveravisuals.media.lyrics;

import java.util.List;

/**
 * Lyrics of one track. Synced lyrics carry a start time per line; plain lyrics are spread over the track
 * length by the consumer. Empty lines are kept out, so every line is something to show.
 */
public record Lyrics(List<Line> lines, boolean synced, String source) {
	public record Line(long timeMillis, String text) {
	}

	public Lyrics {
		lines = List.copyOf(lines);
	}

	public boolean isEmpty() {
		return lines.isEmpty();
	}

	/**
	 * Index of the line that should be showing at {@code positionMillis}, or -1 before the first line. Plain
	 * lyrics are mapped proportionally over {@code durationMillis} (or a steady pace when it is unknown).
	 */
	public int lineAt(long positionMillis, long durationMillis) {
		if (lines.isEmpty()) {
			return -1;
		}
		if (synced) {
			int low = 0;
			int high = lines.size() - 1;
			int found = -1;
			while (low <= high) {
				int middle = (low + high) >>> 1;
				if (lines.get(middle).timeMillis() <= positionMillis) {
					found = middle;
					low = middle + 1;
				} else {
					high = middle - 1;
				}
			}
			return found;
		}
		long perLine = durationMillis > 0 ? Math.max(1500, durationMillis / lines.size()) : 3500;
		return (int) Math.min(lines.size() - 1, Math.max(0, positionMillis) / perLine);
	}
}
