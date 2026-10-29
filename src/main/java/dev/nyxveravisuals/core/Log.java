package dev.nyxveravisuals.core;

import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Client logger. Production output stays quiet; {@link #debug} lines appear only when debug mode is
 * enabled in client settings. {@link #warnOnce}/{@link #errorOnce} protect the console from per-frame spam.
 */
public final class Log {
	private static final Logger LOGGER = LoggerFactory.getLogger(ClientInfo.NAME);
	private static final Set<String> REPORTED = ConcurrentHashMap.newKeySet();
	private static final int MAX_REPORTED = 512;

	private static volatile boolean debugEnabled;

	private Log() {
	}

	public static void setDebugEnabled(boolean enabled) {
		debugEnabled = enabled;
	}

	public static boolean isDebugEnabled() {
		return debugEnabled;
	}

	public static void info(String message, Object... args) {
		LOGGER.info(message, args);
	}

	public static void warn(String message, Object... args) {
		LOGGER.warn(message, args);
	}

	public static void error(String message, Object... args) {
		LOGGER.error(message, args);
	}

	public static void debug(String message, Object... args) {
		if (debugEnabled) {
			LOGGER.info("[debug] " + message, args);
		}
	}

	/** Logs a warning only the first time {@code key} is seen; later occurrences go to debug output. */
	public static void warnOnce(String key, String message, Object... args) {
		if (markReported(key)) {
			LOGGER.warn(message, args);
		} else {
			debug(message, args);
		}
	}

	/** Logs an error only the first time {@code key} is seen; later occurrences go to debug output. */
	public static void errorOnce(String key, String message, Object... args) {
		if (markReported(key)) {
			LOGGER.error(message, args);
		} else {
			debug(message, args);
		}
	}

	private static boolean markReported(String key) {
		if (REPORTED.size() >= MAX_REPORTED) {
			REPORTED.clear();
		}
		return REPORTED.add(key);
	}
}
