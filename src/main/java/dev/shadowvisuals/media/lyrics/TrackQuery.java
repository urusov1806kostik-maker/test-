package dev.shadowvisuals.media.lyrics;

import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.regex.Pattern;

import dev.shadowvisuals.media.MediaInfo;

/**
 * What to search for. Media sessions often report video titles ("Artist - Song (Official Video)") or
 * channel names ("Artist - Topic", "ArtistVEVO"), so {@link #candidates} derives cleaned variants to try in
 * order, most specific first.
 */
public record TrackQuery(String artist, String title, String album, long durationSeconds) {
	private static final Pattern NOISE_BRACKETS = Pattern.compile(
		"\\s*[(\\[【](?:[^)\\]】]*?)(official|video|audio|lyrics?|visuali[sz]er|music video|mv|hd|hq|4k|remaster(?:ed)?|clip|клип|премьера|текст)"
			+ "(?:[^)\\]】]*?)[)\\]】]", Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);
	private static final Pattern FEATURING = Pattern.compile("\\s*[(\\[]?\\s*\\b(feat\\.?|ft\\.?|featuring)\\s+[^)\\]]*[)\\]]?",
		Pattern.CASE_INSENSITIVE);
	private static final Pattern ARTIST_SEPARATORS = Pattern.compile("\\s*(?:,|&|\\bx\\b|\\band\\b|\\bи\\b|;|/)\\s*",
		Pattern.CASE_INSENSITIVE | Pattern.UNICODE_CASE);
	private static final String[] BROWSERS = {"chrome", "msedge", "firefox", "opera", "brave", "yandex", "vivaldi", "browser"};

	public boolean isUsable() {
		return !artist.isBlank() && !title.isBlank();
	}

	public static List<TrackQuery> candidates(MediaInfo info) {
		long duration = info.durationMillis() > 0 ? Math.round(info.durationMillis() / 1000.0) : 0;
		String artist = cleanArtist(info.artist());
		String title = cleanTitle(info.title());
		Set<TrackQuery> result = new LinkedHashSet<>();
		boolean browser = isBrowser(info.sourceApp());
		int dash = title.indexOf(" - ");
		if (dash < 0) {
			dash = title.indexOf(" — ");
		}
		// In browsers the "artist" is usually the channel and the real artist is part of the video title.
		if (dash > 0 && (browser || artist.isEmpty())) {
			String splitArtist = cleanArtist(title.substring(0, dash));
			String splitTitle = cleanTitle(title.substring(dash + 3));
			result.add(new TrackQuery(splitArtist, splitTitle, "", duration));
			result.add(new TrackQuery(primaryArtist(splitArtist), splitTitle, "", duration));
		}
		result.add(new TrackQuery(artist, title, info.album(), duration));
		result.add(new TrackQuery(primaryArtist(artist), title, "", duration));
		if (dash > 0 && !browser && !artist.isEmpty()) {
			result.add(new TrackQuery(artist, cleanTitle(title.substring(dash + 3)), "", duration));
		}
		List<TrackQuery> usable = new ArrayList<>();
		for (TrackQuery query : result) {
			if (query.isUsable()) {
				usable.add(query);
			}
		}
		return usable;
	}

	static String cleanTitle(String title) {
		String cleaned = NOISE_BRACKETS.matcher(title).replaceAll("");
		cleaned = FEATURING.matcher(cleaned).replaceAll("");
		return cleaned.replaceAll("\\s+", " ").replaceAll("[\\s\\-–—|]+$", "").strip();
	}

	static String cleanArtist(String artist) {
		String cleaned = artist.replaceAll("(?i)\\s*-\\s*topic$", "").strip();
		if (cleaned.length() > 4 && cleaned.endsWith("VEVO")) {
			cleaned = cleaned.substring(0, cleaned.length() - 4).strip();
		}
		return FEATURING.matcher(cleaned).replaceAll("").strip();
	}

	static String primaryArtist(String artist) {
		String[] parts = ARTIST_SEPARATORS.split(artist, 2);
		return parts.length > 0 ? parts[0].strip() : artist;
	}

	private static boolean isBrowser(String app) {
		String lower = app.toLowerCase(Locale.ROOT);
		for (String browser : BROWSERS) {
			if (lower.contains(browser)) {
				return true;
			}
		}
		return false;
	}
}
