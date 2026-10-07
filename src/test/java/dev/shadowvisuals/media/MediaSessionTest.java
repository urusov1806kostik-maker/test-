package dev.shadowvisuals.media;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class MediaSessionTest {
	@Test
	void parsesHelperOutput() {
		MediaInfo info = WindowsMediaSession.parse("{\"state\":\"ok\",\"title\":\"Song\",\"artist\":\"Band\",\"album\":\"\",\"app\":\"Spotify.exe\","
			+ "\"status\":\"Playing\",\"position\":15000.0,\"duration\":200000.0,\"updated\":1000.0}");
		assertNotNull(info);
		assertTrue(info.playing());
		assertEquals("Song", info.title());
		assertEquals(17_000, info.positionAt(3_000));
		assertEquals(200_000, info.positionAt(10_000_000));
		assertNull(WindowsMediaSession.parse("{\"state\":\"none\"}"));
		assertNull(WindowsMediaSession.parse("{\"state\":\"ok\",\"title\":\"\"}"));
	}

	@Test
	void pausedTracksDoNotAdvance() {
		MediaInfo paused = new MediaInfo("Song", "Band", "", "", false, 5_000, 100_000, 1_000);
		assertEquals(5_000, paused.positionAt(50_000));
		assertFalse(paused.trackKey().isEmpty());
		assertEquals(new MediaInfo("song", "BAND", "", "", true, 0, 0, 0).trackKey(), paused.trackKey());
	}
}
