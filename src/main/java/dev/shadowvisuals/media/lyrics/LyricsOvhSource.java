package dev.shadowvisuals.media.lyrics;

import java.io.IOException;
import java.net.http.HttpClient;
import java.util.Optional;

import com.google.gson.JsonElement;
import com.google.gson.JsonParser;

/** <a href="https://lyrics.ovh">lyrics.ovh</a>: plain (unsynced) lyrics by artist and title. */
public final class LyricsOvhSource implements LyricsSource {
	private static final String API = "https://api.lyrics.ovh/v1/";

	@Override
	public String id() {
		return "lyrics_ovh";
	}

	@Override
	public Optional<Lyrics> find(TrackQuery query, HttpClient http) throws IOException, InterruptedException {
		String body = LyricsSource.get(http, API + LyricsSource.pathSegment(query.artist()) + "/" + LyricsSource.pathSegment(query.title()));
		return body == null ? Optional.empty() : parse(body);
	}

	static Optional<Lyrics> parse(String body) {
		JsonElement element = JsonParser.parseString(body);
		if (!element.isJsonObject() || !element.getAsJsonObject().has("lyrics")) {
			return Optional.empty();
		}
		String text = element.getAsJsonObject().get("lyrics").getAsString();
		// The service sometimes prefixes a French "Paroles de la chanson ... par ..." header line.
		if (text.startsWith("Paroles de la chanson")) {
			int newline = text.indexOf('\n');
			text = newline >= 0 ? text.substring(newline + 1) : "";
		}
		Lyrics lyrics = LyricsParser.parsePlain(text, "lyrics.ovh");
		return lyrics.isEmpty() ? Optional.empty() : Optional.of(lyrics);
	}
}
