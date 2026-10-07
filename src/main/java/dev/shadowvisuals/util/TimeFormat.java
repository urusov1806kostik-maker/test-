package dev.shadowvisuals.util;

public final class TimeFormat {
	private TimeFormat() {
	}

	/** {@code 1:05:09} or {@code 05:09} for durations under an hour. */
	public static String duration(long millis) {
		long totalSeconds = Math.max(0, millis / 1000);
		long hours = totalSeconds / 3600;
		long minutes = (totalSeconds % 3600) / 60;
		long seconds = totalSeconds % 60;
		StringBuilder out = new StringBuilder(10);
		if (hours > 0) {
			Numbers.appendTwoDigits(out.append(hours).append(':'), minutes);
		} else {
			Numbers.appendTwoDigits(out, minutes);
		}
		return Numbers.appendTwoDigits(out.append(':'), seconds).toString();
	}

	/** Seconds with one decimal below 10 s ({@code 4.2s}), whole seconds above. */
	public static String seconds(float seconds) {
		return Numbers.fixed(seconds, seconds < 10f ? 1 : 0) + "s";
	}
}
