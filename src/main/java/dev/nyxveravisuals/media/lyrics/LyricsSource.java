package dev.nyxveravisuals.media.lyrics;

import java.io.IOException;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Optional;

import dev.nyxveravisuals.core.ClientInfo;

/** One lyrics provider. Implementations are stateless and are called from the lyrics worker thread only. */
public interface LyricsSource {
	Duration REQUEST_TIMEOUT = Duration.ofSeconds(10);

	String id();

	/** Lyrics for {@code query}, or empty when the provider does not know the track. */
	Optional<Lyrics> find(TrackQuery query, HttpClient http) throws IOException, InterruptedException;

	/** GET returning the body for 200 responses and {@code null} for 404; other statuses are errors. */
	static String get(HttpClient http, String url) throws IOException, InterruptedException {
		HttpRequest request = HttpRequest.newBuilder(URI.create(url))
			.timeout(REQUEST_TIMEOUT)
			.header("User-Agent", ClientInfo.NAME.replace(' ', '-') + "/" + ClientInfo.version())
			.header("Accept", "application/json")
			.GET()
			.build();
		HttpResponse<String> response = http.send(request, HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
		if (response.statusCode() == 404) {
			return null;
		}
		if (response.statusCode() / 100 != 2) {
			throw new IOException("HTTP " + response.statusCode() + " from " + request.uri().getHost());
		}
		return response.body();
	}

	static String query(String value) {
		return URLEncoder.encode(value, StandardCharsets.UTF_8);
	}

	static String pathSegment(String value) {
		return URLEncoder.encode(value, StandardCharsets.UTF_8).replace("+", "%20");
	}
}
