package dev.shadowvisuals.media.lyrics;

import java.io.IOException;
import java.net.http.HttpClient;
import java.util.Optional;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

/**
 * <a href="https://lrclib.net">LRCLIB</a>: open lyrics database with time-synced lyrics. Tries the exact
 * lookup (artist, title, album, duration) first and falls back to search, preferring synced results with the
 * closest duration.
 */
public final class LrclibSource implements LyricsSource {
	private static final String API = "https://lrclib.net/api/";

	@Override
	public String id() {
		return "lrclib";
	}

	@Override
	public Optional<Lyrics> find(TrackQuery query, HttpClient http) throws IOException, InterruptedException {
		if (!query.album().isBlank() && query.durationSeconds() > 0) {
			String body = LyricsSource.get(http, API + "get?artist_name=" + LyricsSource.query(query.artist())
				+ "&track_name=" + LyricsSource.query(query.title()) + "&album_name=" + LyricsSource.query(query.album())
				+ "&duration=" + query.durationSeconds());
			if (body != null) {
				JsonElement element = JsonParser.parseString(body);
				if (element.isJsonObject()) {
					Optional<Lyrics> exact = fromRecord(element.getAsJsonObject());
					if (exact.isPresent()) {
						return exact;
					}
				}
			}
		}
		String body = LyricsSource.get(http, API + "search?artist_name=" + LyricsSource.query(query.artist())
			+ "&track_name=" + LyricsSource.query(query.title()));
		if (body == null) {
			return Optional.empty();
		}
		JsonElement element = JsonParser.parseString(body);
		return element.isJsonArray() ? best(element.getAsJsonArray(), query.durationSeconds()) : Optional.empty();
	}

	/** Picks the best search result: synced beats plain, then the closest duration (when known). */
	static Optional<Lyrics> best(JsonArray results, long durationSeconds) {
		JsonObject chosen = null;
		double chosenScore = Double.MAX_VALUE;
		for (JsonElement element : results) {
			if (!element.isJsonObject()) {
				continue;
			}
			JsonObject record = element.getAsJsonObject();
			boolean synced = hasText(record, "syncedLyrics");
			if (!synced && !hasText(record, "plainLyrics")) {
				continue;
			}
			double difference = durationSeconds > 0 && record.has("duration") && record.get("duration").isJsonPrimitive()
				? Math.abs(record.get("duration").getAsDouble() - durationSeconds) : 0;
			if (durationSeconds > 0 && difference > 15) {
				continue;
			}
			double score = difference + (synced ? 0 : 1000);
			if (score < chosenScore) {
				chosen = record;
				chosenScore = score;
			}
		}
		return chosen == null ? Optional.empty() : fromRecord(chosen);
	}

	static Optional<Lyrics> fromRecord(JsonObject record) {
		if (hasText(record, "syncedLyrics")) {
			Lyrics synced = LyricsParser.parseSynced(record.get("syncedLyrics").getAsString(), "LRCLIB");
			if (!synced.isEmpty()) {
				return Optional.of(synced);
			}
		}
		if (hasText(record, "plainLyrics")) {
			Lyrics plain = LyricsParser.parsePlain(record.get("plainLyrics").getAsString(), "LRCLIB");
			if (!plain.isEmpty()) {
				return Optional.of(plain);
			}
		}
		return Optional.empty();
	}

	private static boolean hasText(JsonObject record, String key) {
		JsonElement value = record.get(key);
		return value != null && value.isJsonPrimitive() && !value.getAsString().isBlank();
	}
}
