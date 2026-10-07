package dev.shadowvisuals.media.lyrics;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Turns LRC (time-tagged) and plain lyric text into {@link Lyrics}. */
public final class LyricsParser {
	private static final Pattern TIME_TAG = Pattern.compile("\\[(\\d{1,3}):(\\d{1,2})(?:[.:](\\d{1,3}))?]");
	private static final Pattern OFFSET_TAG = Pattern.compile("^\\[offset:\\s*([+-]?\\d+)\\s*]$", Pattern.CASE_INSENSITIVE);
	private static final Pattern META_TAG = Pattern.compile("^\\[[a-zA-Z#]+:.*]$");
	private static final int MAX_LINE_LENGTH = 160;

	private LyricsParser() {
	}

	/**
	 * Parses LRC: {@code [mm:ss.xx]text}, several time tags per line, an optional {@code [offset:ms]} tag and
	 * metadata tags (ignored). Returns empty lyrics when no time tag is found.
	 */
	public static Lyrics parseSynced(String text, String source) {
		List<Lyrics.Line> lines = new ArrayList<>();
		long offset = 0;
		for (String raw : text.split("\\R")) {
			String line = raw.strip();
			Matcher offsetMatch = OFFSET_TAG.matcher(line);
			if (offsetMatch.matches()) {
				offset = Long.parseLong(offsetMatch.group(1));
				continue;
			}
			Matcher tags = TIME_TAG.matcher(line);
			List<Long> times = new ArrayList<>(2);
			int end = 0;
			while (tags.find() && tags.start() == end) {
				times.add(toMillis(tags.group(1), tags.group(2), tags.group(3)));
				end = tags.end();
			}
			if (times.isEmpty()) {
				continue;
			}
			String lyric = clean(line.substring(end));
			if (lyric.isEmpty()) {
				continue;
			}
			for (long time : times) {
				lines.add(new Lyrics.Line(time, lyric));
			}
		}
		// A positive LRC offset means the lyrics should appear earlier.
		long shift = offset;
		List<Lyrics.Line> shifted = new ArrayList<>(lines.size());
		for (Lyrics.Line line : lines) {
			shifted.add(new Lyrics.Line(Math.max(0, line.timeMillis() - shift), line.text()));
		}
		shifted.sort(Comparator.comparingLong(Lyrics.Line::timeMillis));
		return new Lyrics(shifted, true, source);
	}

	/** Plain lyrics: one entry per non-empty line, section headers such as {@code [Chorus]} dropped. */
	public static Lyrics parsePlain(String text, String source) {
		List<Lyrics.Line> lines = new ArrayList<>();
		for (String raw : text.split("\\R")) {
			String line = clean(raw);
			if (line.isEmpty() || META_TAG.matcher(line).matches() || line.startsWith("[") && line.endsWith("]")) {
				continue;
			}
			lines.add(new Lyrics.Line(-1, line));
		}
		return new Lyrics(lines, false, source);
	}

	private static long toMillis(String minutes, String seconds, String fraction) {
		long millis = Long.parseLong(minutes) * 60_000 + Long.parseLong(seconds) * 1000;
		if (fraction != null) {
			// "5" = 500 ms, "05" = 50 ms, "005" = 5 ms
			String padded = (fraction + "00").substring(0, 3);
			millis += Long.parseLong(padded);
		}
		return millis;
	}

	private static String clean(String text) {
		String line = text.replace('\t', ' ').replaceAll("\\s+", " ").strip();
		return line.length() > MAX_LINE_LENGTH ? line.substring(0, MAX_LINE_LENGTH - 1).strip() + "…" : line;
	}
}
