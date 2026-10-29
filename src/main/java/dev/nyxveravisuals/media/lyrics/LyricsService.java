package dev.nyxveravisuals.media.lyrics;

import java.io.IOException;
import java.net.http.HttpClient;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HexFormat;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.RejectedExecutionException;

import com.google.gson.JsonArray;
import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.google.gson.JsonParser;

import dev.nyxveravisuals.config.JsonFiles;
import dev.nyxveravisuals.core.Log;
import dev.nyxveravisuals.media.MediaInfo;

/**
 * Finds lyrics for tracks on a single background thread, trying every query variant against every source in
 * order. Results are cached in memory (bounded LRU), found lyrics also on disk (bounded file count) so the
 * same song is never downloaded twice, and misses are remembered for a while to avoid hammering the APIs.
 */
public final class LyricsService implements AutoCloseable {
	public enum State {
		SEARCHING,
		FOUND,
		NOT_FOUND
	}

	public record Result(State state, Lyrics lyrics) {
		static final Result SEARCHING = new Result(State.SEARCHING, null);
		static final Result NOT_FOUND = new Result(State.NOT_FOUND, null);
	}

	private static final int MEMORY_ENTRIES = 64;
	private static final int DISK_ENTRIES = 300;
	private static final long MISS_RETRY_MILLIS = 20 * 60_000L;
	private static final int CACHE_FORMAT = 1;

	private final List<LyricsSource> sources;
	private final Path cacheDirectory;
	private final Map<String, Result> memory = new LinkedHashMap<>(32, 0.75f, true) {
		@Override
		protected boolean removeEldestEntry(Map.Entry<String, Result> eldest) {
			return size() > MEMORY_ENTRIES;
		}
	};
	private final Map<String, Long> misses = new ConcurrentHashMap<>();
	private final Map<String, Result> completed = new ConcurrentHashMap<>();
	private final ExecutorService worker;
	private HttpClient http;

	public LyricsService(List<LyricsSource> sources, Path cacheDirectory) {
		this.sources = List.copyOf(sources);
		this.cacheDirectory = cacheDirectory;
		this.worker = Executors.newSingleThreadExecutor(runnable -> {
			Thread thread = new Thread(runnable, "NyxveraVisuals lyrics");
			thread.setDaemon(true);
			return thread;
		});
	}

	public static List<LyricsSource> defaultSources() {
		return List.of(new LrclibSource(), new LyricsOvhSource());
	}

	/** Current result for {@code track}; starts a lookup the first time a track is asked for. Client thread. */
	public Result lookup(MediaInfo track) {
		String key = track.trackKey();
		Result finished = completed.remove(key);
		if (finished != null) {
			memory.put(key, finished);
		}
		Result cached = memory.get(key);
		if (cached != null) {
			if (cached.state() != State.NOT_FOUND || !missExpired(key)) {
				return cached;
			}
		}
		memory.put(key, Result.SEARCHING);
		try {
			worker.execute(() -> completed.put(key, resolve(key, track)));
		} catch (RejectedExecutionException e) {
			return Result.NOT_FOUND;
		}
		return Result.SEARCHING;
	}

	private boolean missExpired(String key) {
		Long since = misses.get(key);
		return since == null || System.currentTimeMillis() - since > MISS_RETRY_MILLIS;
	}

	private Result resolve(String key, MediaInfo track) {
		Optional<Lyrics> fromDisk = readDisk(key);
		if (fromDisk.isPresent()) {
			return new Result(State.FOUND, fromDisk.get());
		}
		List<TrackQuery> queries = TrackQuery.candidates(track);
		for (TrackQuery query : queries) {
			for (LyricsSource source : sources) {
				try {
					Optional<Lyrics> found = source.find(query, client());
					if (found.isPresent()) {
						writeDisk(key, found.get());
						misses.remove(key);
						return new Result(State.FOUND, found.get());
					}
				} catch (InterruptedException e) {
					Thread.currentThread().interrupt();
					return Result.NOT_FOUND;
				} catch (IOException | RuntimeException e) {
					Log.debug("Lyrics source {} failed for {} - {}: {}", source.id(), query.artist(), query.title(), e.toString());
				}
			}
		}
		misses.put(key, System.currentTimeMillis());
		return Result.NOT_FOUND;
	}

	private HttpClient client() {
		if (http == null) {
			http = HttpClient.newBuilder()
				.connectTimeout(Duration.ofSeconds(6))
				.followRedirects(HttpClient.Redirect.NORMAL)
				.build();
		}
		return http;
	}

	private Path cacheFile(String key) {
		try {
			byte[] digest = MessageDigest.getInstance("SHA-256").digest(key.getBytes(StandardCharsets.UTF_8));
			return cacheDirectory.resolve(HexFormat.of().formatHex(digest, 0, 16) + ".json");
		} catch (NoSuchAlgorithmException e) {
			throw new IllegalStateException("SHA-256 is always available", e);
		}
	}

	Optional<Lyrics> readDisk(String key) {
		Path file = cacheFile(key);
		if (!Files.isRegularFile(file)) {
			return Optional.empty();
		}
		try {
			JsonElement root = JsonParser.parseString(Files.readString(file, StandardCharsets.UTF_8));
			if (!root.isJsonObject()) {
				return Optional.empty();
			}
			JsonObject json = root.getAsJsonObject();
			if (json.get("format").getAsInt() != CACHE_FORMAT || !key.equals(json.get("key").getAsString())) {
				return Optional.empty();
			}
			List<Lyrics.Line> lines = new ArrayList<>();
			for (JsonElement element : json.getAsJsonArray("lines")) {
				JsonObject line = element.getAsJsonObject();
				lines.add(new Lyrics.Line(line.get("t").getAsLong(), line.get("text").getAsString()));
			}
			// Touch the file so the size limit evicts the least recently played songs first.
			Files.setLastModifiedTime(file, java.nio.file.attribute.FileTime.fromMillis(System.currentTimeMillis()));
			return Optional.of(new Lyrics(lines, json.get("synced").getAsBoolean(), json.get("source").getAsString()));
		} catch (IOException | JsonParseException | IllegalStateException | UnsupportedOperationException | NullPointerException
			| ClassCastException e) {
			Log.debug("Ignoring unreadable lyrics cache file {}: {}", file.getFileName(), e.toString());
			return Optional.empty();
		}
	}

	void writeDisk(String key, Lyrics lyrics) {
		JsonObject json = new JsonObject();
		json.addProperty("format", CACHE_FORMAT);
		json.addProperty("key", key);
		json.addProperty("source", lyrics.source());
		json.addProperty("synced", lyrics.synced());
		JsonArray lines = new JsonArray();
		for (Lyrics.Line line : lyrics.lines()) {
			JsonObject entry = new JsonObject();
			entry.addProperty("t", line.timeMillis());
			entry.addProperty("text", line.text());
			lines.add(entry);
		}
		json.add("lines", lines);
		try {
			Files.createDirectories(cacheDirectory);
			JsonFiles.writeAtomic(cacheFile(key), json);
			prune();
		} catch (IOException e) {
			Log.warnOnce("lyrics-cache-write", "Could not write the lyrics cache in {}: {}", cacheDirectory, e.toString());
		}
	}

	private void prune() throws IOException {
		List<Path> files;
		try (var stream = Files.list(cacheDirectory)) {
			files = stream.filter(path -> path.getFileName().toString().endsWith(".json")).toList();
		}
		if (files.size() <= DISK_ENTRIES) {
			return;
		}
		List<Path> oldestFirst = new ArrayList<>(files);
		oldestFirst.sort(Comparator.comparingLong(LyricsService::modified));
		for (int i = 0; i < oldestFirst.size() - DISK_ENTRIES; i++) {
			Files.deleteIfExists(oldestFirst.get(i));
		}
	}

	private static long modified(Path path) {
		try {
			return Files.getLastModifiedTime(path).toMillis();
		} catch (IOException e) {
			return 0;
		}
	}

	@Override
	public void close() {
		worker.shutdownNow();
		memory.clear();
		completed.clear();
	}
}
