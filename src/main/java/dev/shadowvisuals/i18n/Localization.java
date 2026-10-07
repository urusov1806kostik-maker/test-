package dev.shadowvisuals.i18n;

import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;
import java.util.function.Function;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParseException;
import com.google.gson.JsonParser;

import dev.shadowvisuals.core.Log;
import dev.shadowvisuals.setting.ModeSetting;
import dev.shadowvisuals.setting.SettingNode;

/**
 * Client UI strings, independent from the game's language list so the client can follow the game language
 * or use its own. Files live in {@code assets/shadowvisuals/i18n/<code>.json}; English is the fallback.
 * Adding a language only requires a new JSON file and a {@link Language} constant.
 */
public final class Localization {
	public enum Language {
		AUTO(null),
		ENGLISH("en_us"),
		RUSSIAN("ru_ru"),
		UKRAINIAN("uk_ua");

		private final String code;

		Language(String code) {
			this.code = code;
		}

		public String code() {
			return code;
		}
	}

	public static final String FALLBACK_CODE = "en_us";
	private static final String PATH = "/assets/shadowvisuals/i18n/%s.json";

	private final Function<String, InputStream> opener;
	private final Map<String, String> fallback;
	private Map<String, String> current;
	private String currentCode = FALLBACK_CODE;
	private int revision;

	public Localization() {
		this(path -> Localization.class.getResourceAsStream(path));
	}

	public Localization(Function<String, InputStream> opener) {
		this.opener = opener;
		this.fallback = loadFile(FALLBACK_CODE);
		this.current = fallback;
	}

	/** Resolves {@code language} (AUTO uses {@code gameLanguageCode}) and loads it if it changed. */
	public void select(Language language, String gameLanguageCode) {
		String code = language == Language.AUTO ? normalize(gameLanguageCode) : language.code();
		if (code.equals(currentCode)) {
			return;
		}
		Map<String, String> loaded = code.equals(FALLBACK_CODE) ? fallback : loadFile(code);
		current = loaded.isEmpty() ? fallback : loaded;
		currentCode = loaded.isEmpty() ? FALLBACK_CODE : code;
		revision++;
	}

	private static String normalize(String gameCode) {
		if (gameCode == null) {
			return FALLBACK_CODE;
		}
		String lower = gameCode.toLowerCase(Locale.ROOT);
		for (Language language : Language.values()) {
			if (language.code() != null && language.code().equals(lower)) {
				return lower;
			}
		}
		// Belarusian and Kazakh players usually prefer Russian over English.
		return switch (lower) {
			case "be_by", "kk_kz" -> "ru_ru";
			default -> FALLBACK_CODE;
		};
	}

	private Map<String, String> loadFile(String code) {
		Map<String, String> map = new HashMap<>();
		String path = String.format(Locale.ROOT, PATH, code);
		try (InputStream stream = opener.apply(path)) {
			if (stream == null) {
				Log.warn("Missing translation file {}", path);
				return map;
			}
			JsonElement root = JsonParser.parseReader(new InputStreamReader(stream, StandardCharsets.UTF_8));
			if (root.isJsonObject()) {
				flatten("", root.getAsJsonObject(), map);
			}
		} catch (IOException | JsonParseException | IllegalStateException e) {
			Log.error("Could not read translation file {}", path, e);
		}
		return map;
	}

	private static void flatten(String prefix, JsonObject object, Map<String, String> out) {
		for (Map.Entry<String, JsonElement> entry : object.entrySet()) {
			String key = prefix.isEmpty() ? entry.getKey() : prefix + "." + entry.getKey();
			if (entry.getValue().isJsonObject()) {
				flatten(key, entry.getValue().getAsJsonObject(), out);
			} else if (entry.getValue().isJsonPrimitive()) {
				out.put(key, entry.getValue().getAsString());
			}
		}
	}

	public String languageCode() {
		return currentCode;
	}

	/** Increments whenever the language changes; lets UI caches invalidate cheaply. */
	public int revision() {
		return revision;
	}

	public boolean has(String key) {
		return current.containsKey(key) || fallback.containsKey(key);
	}

	/** Translation, English fallback, or a humanized key. Never returns {@code null}. */
	public String tr(String key) {
		String value = current.get(key);
		if (value == null) {
			value = fallback.get(key);
		}
		if (value == null) {
			Log.debug("Missing translation key {}", key);
			return humanize(key);
		}
		return value;
	}

	/** Translation with {@code {0}}, {@code {1}}... placeholders replaced by {@code args}. */
	public String tr(String key, Object... args) {
		String value = tr(key);
		for (int i = 0; i < args.length; i++) {
			value = value.replace("{" + i + "}", String.valueOf(args[i]));
		}
		return value;
	}

	/** Returns the translation of {@code key}, or {@code null} if neither language defines it. */
	public String find(String key) {
		String value = current.get(key);
		return value != null ? value : fallback.get(key);
	}

	public String settingName(SettingNode node) {
		String value = find(node.translationKey());
		if (value == null) {
			value = find(node.genericTranslationKey());
		}
		return value != null ? value : humanize(node.id());
	}

	/** Description shown in tooltips, or {@code null} when the setting is self-explanatory. */
	public String settingDescription(SettingNode node) {
		String value = find(node.descriptionKey());
		return value != null ? value : find(node.genericTranslationKey() + ".desc");
	}

	public String enumName(Enum<?> constant) {
		String value = find(ModeSetting.keyOf(constant));
		return value != null ? value : humanize(constant.name().toLowerCase(Locale.ROOT));
	}

	/** {@code module.esp.setting.max_distance} becomes "Max distance". */
	public static String humanize(String key) {
		int dot = key.lastIndexOf('.');
		String last = dot >= 0 ? key.substring(dot + 1) : key;
		if ((last.equals("name") || last.equals("description")) && dot > 0) {
			// module.<id>.name -> humanized id
			int previous = key.lastIndexOf('.', dot - 1);
			last = key.substring(previous + 1, dot);
		}
		if (last.isEmpty()) {
			return key;
		}
		String spaced = last.replace('_', ' ');
		return Character.toUpperCase(spaced.charAt(0)) + spaced.substring(1);
	}
}
