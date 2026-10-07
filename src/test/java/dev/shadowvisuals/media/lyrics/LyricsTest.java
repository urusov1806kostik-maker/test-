package dev.shadowvisuals.media.lyrics;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.Optional;

import com.google.gson.JsonParser;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.io.TempDir;

import dev.shadowvisuals.media.MediaInfo;

class LyricsTest {
	@Test
	void parsesSyncedLyricsWithMultipleTagsAndOffset() {
		String lrc = """
			[ar:Someone]
			[offset:+500]
			[00:01.00]alpha line
			[00:05.50][00:20.00]beta line
			[00:09.5]gamma line
			[00:12.00]
			""";
		Lyrics lyrics = LyricsParser.parseSynced(lrc, "test");
		assertTrue(lyrics.synced());
		assertEquals(List.of("alpha line", "beta line", "gamma line", "beta line"), lyrics.lines().stream().map(Lyrics.Line::text).toList());
		assertEquals(500, lyrics.lines().get(0).timeMillis());
		assertEquals(5000, lyrics.lines().get(1).timeMillis());
		assertEquals(9000, lyrics.lines().get(2).timeMillis());
		assertEquals(-1, lyrics.lineAt(100, 0));
		assertEquals(0, lyrics.lineAt(4999, 0));
		assertEquals(2, lyrics.lineAt(15_000, 0));
		assertEquals(3, lyrics.lineAt(60_000, 0));
	}

	@Test
	void plainLyricsDropSectionHeadersAndSpreadOverTheTrack() {
		Lyrics lyrics = LyricsParser.parsePlain("[Verse 1]\nfirst\n\n  second  \n[Chorus]\nthird\nfourth", "test");
		assertFalse(lyrics.synced());
		assertEquals(4, lyrics.lines().size());
		assertEquals("second", lyrics.lines().get(1).text());
		assertEquals(0, lyrics.lineAt(0, 40_000));
		assertEquals(2, lyrics.lineAt(20_000, 40_000));
		assertEquals(3, lyrics.lineAt(400_000, 40_000));
	}

	@Test
	void cleansVideoTitlesAndChannelNames() {
		assertEquals("Song Name", TrackQuery.cleanTitle("Song Name (Official Music Video)"));
		assertEquals("Song Name", TrackQuery.cleanTitle("Song Name [Lyrics] feat. Other Person"));
		assertEquals("Песня", TrackQuery.cleanTitle("Песня (Премьера клипа, 2024)"));
		assertEquals("Band", TrackQuery.cleanArtist("Band - Topic"));
		assertEquals("Singer", TrackQuery.cleanArtist("SingerVEVO"));
		assertEquals("First", TrackQuery.primaryArtist("First & Second"));

		MediaInfo browser = new MediaInfo("Band - Song Name (Official Video)", "Some Channel", "", "chrome.exe", true, 0, 200_000, 0);
		TrackQuery first = TrackQuery.candidates(browser).get(0);
		assertEquals("Band", first.artist());
		assertEquals("Song Name", first.title());
		assertEquals(200, first.durationSeconds());

		MediaInfo app = new MediaInfo("Song Name", "Band, Guest", "Album", "Spotify.exe", true, 0, 0, 0);
		List<TrackQuery> candidates = TrackQuery.candidates(app);
		assertEquals(new TrackQuery("Band, Guest", "Song Name", "Album", 0), candidates.get(0));
		assertEquals("Band", candidates.get(1).artist());
	}

	@Test
	void lrclibPrefersSyncedResultsWithMatchingDuration() {
		String body = """
			[
			  {"duration": 300, "plainLyrics": "far plain"},
			  {"duration": 181, "plainLyrics": "near plain"},
			  {"duration": 183, "syncedLyrics": "[00:01.00]near synced"},
			  {"duration": 180, "instrumental": true}
			]""";
		Optional<Lyrics> best = LrclibSource.best(JsonParser.parseString(body).getAsJsonArray(), 180);
		assertTrue(best.isPresent());
		assertTrue(best.get().synced());
		assertEquals("near synced", best.get().lines().get(0).text());
	}

	@Test
	void lyricsOvhStripsTheHeaderLine() {
		Optional<Lyrics> lyrics = LyricsOvhSource.parse("{\"lyrics\":\"Paroles de la chanson X par Y\\r\\nfirst\\nsecond\"}");
		assertEquals(List.of("first", "second"), lyrics.orElseThrow().lines().stream().map(Lyrics.Line::text).toList());
		assertTrue(LyricsOvhSource.parse("{\"error\":\"No lyrics found\"}").isEmpty());
	}

	@Test
	void diskCacheRoundTrips(@TempDir Path directory) throws Exception {
		LyricsService service = new LyricsService(List.of(), directory);
		try {
			Lyrics lyrics = new Lyrics(List.of(new Lyrics.Line(1000, "cached line")), true, "test");
			service.writeDisk("band\u0000song", lyrics);
			assertEquals(lyrics, service.readDisk("band\u0000song").orElseThrow());
			assertTrue(service.readDisk("other\u0000song").isEmpty());
			try (var files = Files.list(directory)) {
				assertEquals(1, files.count());
			}
		} finally {
			service.close();
		}
	}
}
