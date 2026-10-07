package dev.shadowvisuals.util;

import java.util.Locale;

public final class TimeFormat {
	private TimeFormat() {
	}

	/** {@code 1:05:09} or {@code 05:09} for durations under an hour. */
	public static String duration(long millis) {
		long totalSeconds = Math.max(0, millis / 1000);
		long hours = totalSeconds / 3600;
		long minutes = (totalSeconds % 3600) / 60;
		long seconds = totalSeconds % 60;
		return hours > 0
			? String.format(Locale.ROOT, "%d:%02d:%02d", hours, minutes, seconds)
			: String.format(Locale.ROOT, "%02d:%02d", minutes, seconds);
	}

	/** Seconds with one decimal below 10 s ({@code 4.2s}), whole seconds above. */
	public static String seconds(float seconds) {
		return seconds < 10f ? String.format(Locale.ROOT, "%.1fs", seconds) : String.format(Locale.ROOT, "%.0fs", seconds);
	}
}
