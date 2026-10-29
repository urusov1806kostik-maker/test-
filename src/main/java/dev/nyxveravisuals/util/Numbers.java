package dev.nyxveravisuals.util;

/**
 * Fast fixed-point number formatting for HUD text that changes every frame. Equivalent to
 * {@code String.format(Locale.ROOT, "%.<n>f", value)} for display purposes, without parsing a format string.
 */
public final class Numbers {
	private static final long[] POWERS = {1, 10, 100, 1000, 10000};

	private Numbers() {
	}

	/** {@code value} with exactly {@code decimals} (0-4) digits after the point, rounded half up. */
	public static String fixed(double value, int decimals) {
		return appendFixed(new StringBuilder(12), value, decimals).toString();
	}

	public static StringBuilder appendFixed(StringBuilder out, double value, int decimals) {
		if (!Double.isFinite(value)) {
			return out.append(value);
		}
		int digits = Math.clamp(decimals, 0, POWERS.length - 1);
		long scale = POWERS[digits];
		long scaled = Math.round(Math.abs(value) * scale);
		if (value < 0 && scaled != 0) {
			out.append('-');
		}
		out.append(scaled / scale);
		if (digits > 0) {
			out.append('.');
			long fraction = scaled % scale;
			for (long limit = scale / 10; limit > fraction && limit > 1; limit /= 10) {
				out.append('0');
			}
			out.append(fraction);
		}
		return out;
	}

	/** Two-digit zero padded value, for clock-style output. */
	public static StringBuilder appendTwoDigits(StringBuilder out, long value) {
		if (value < 10) {
			out.append('0');
		}
		return out.append(value);
	}
}
