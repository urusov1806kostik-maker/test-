package dev.nyxveravisuals.modules.visual;

import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;
import java.util.Set;
import java.util.concurrent.ThreadLocalRandom;

import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.Font;
import net.minecraft.client.player.LocalPlayer;
import net.minecraft.util.Mth;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.animation.AnimationClock;
import dev.nyxveravisuals.animation.Easing;
import dev.nyxveravisuals.event.events.ClientTickEvent;
import dev.nyxveravisuals.event.events.WorldLeaveEvent;
import dev.nyxveravisuals.event.events.WorldRenderEvent;
import dev.nyxveravisuals.media.MediaInfo;
import dev.nyxveravisuals.media.MediaSource;
import dev.nyxveravisuals.media.WindowsMediaSession;
import dev.nyxveravisuals.media.lyrics.Lyrics;
import dev.nyxveravisuals.media.lyrics.LrclibSource;
import dev.nyxveravisuals.media.lyrics.LyricsOvhSource;
import dev.nyxveravisuals.media.lyrics.LyricsService;
import dev.nyxveravisuals.media.lyrics.LyricsSource;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.WorldRenderer3D;
import dev.nyxveravisuals.setting.ActionSetting;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.IntSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.MultiSelectSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * Song lyrics as a 3D effect around the player. The playing track comes from the system media session, the
 * lyrics from online sources (cached), and every new line floats in at a spot next to the player — left,
 * right, above or around, depending on the placement mode — then drifts and fades out. Synced lyrics follow
 * the playback position; plain lyrics are spread over the track length.
 */
public final class MusicLyrics extends Module {
	public enum Placement {
		AROUND,
		LEFT_RIGHT,
		TOP,
		DYNAMIC
	}

	public enum Appear {
		FADE,
		RISE,
		POP,
		TYPEWRITER
	}

	public enum Source {
		LRCLIB,
		LYRICS_OVH
	}

	private enum Kind {
		LYRIC,
		TITLE,
		STATUS
	}

	private static final int MAX_POOL = 16;
	private static final int WRAP_WIDTH = 220;
	private static final double PREVIEW_LINE_SECONDS = 2.6;
	private static final int PREVIEW_LINES = 6;
	private static final float GOLDEN_ANGLE = 137.508f;
	/** Size 1.0 maps to 40% of name-tag text: a typical line is about a block and a half wide at 2-3 m. */
	private static final float TEXT_SCALE = 0.4f;

	private final NyxveraClient client;
	private final ModeSetting<Placement> placement = settings().add(new ModeSetting<>("placement", Placement.AROUND));
	private final ModeSetting<Appear> appear = settings().add(new ModeSetting<>("appear", Appear.RISE));
	private final NumberSetting depth = settings().add(new NumberSetting("depth", 1.0, 0.0, 3.0, 0.1));
	private final NumberSetting size = settings().add(new NumberSetting("size", 1.0, 0.3, 3.0, 0.05).suffix("x"));
	private final ColorSetting color = settings().add(new ColorSetting("color", 0xFFF4F2FF, true));
	private final ColorSetting highlight = settings().add(new ColorSetting("highlight_color", 0xFF8B7CF6, true));
	private final NumberSetting opacity = settings().add(new NumberSetting("opacity", 0.95, 0.1, 1.0, 0.05));
	private final NumberSetting distance = settings().add(new NumberSetting("distance", 2.4, 0.8, 6.0, 0.1).suffix("m"));
	private final NumberSetting appearTime = settings().add(new NumberSetting("appear_time", 0.6, 0.1, 2.0, 0.05).suffix("s"));
	private final IntSetting maxLines = settings().add(new IntSetting("max_lines", 4, 1, 8));
	private final NumberSetting lineLife = settings().add(new NumberSetting("line_life", 9, 2, 30, 0.5).suffix("s"));
	private final BooleanSetting floatMotion = settings().add(new BooleanSetting("float_motion", true));
	private final BooleanSetting showTrack = settings().add(new BooleanSetting("show_track", true));
	private final BooleanSetting throughWalls = settings().add(new BooleanSetting("through_walls", false));
	private final IntSetting syncOffset = settings().add(new IntSetting("sync_offset", 0, -3000, 3000, 50).suffix("ms"));
	private final MultiSelectSetting<Source> sources = settings().add(new MultiSelectSetting<>("sources", Source.class, Source.LRCLIB, Source.LYRICS_OVH));
	private final ActionSetting preview = settings().add(new ActionSetting("preview", this::startPreview));

	private final List<FloatingLine> lines = new ArrayList<>();
	private MediaSource media;
	private LyricsService service;
	private Set<Source> serviceSources = EnumSet.noneOf(Source.class);
	private String trackKey;
	private int lastIndex = -1;
	private String statusKey;
	private int spawnCounter;
	private double previewStart = -1;
	private int previewIndex = -1;

	/** One floating line. Placement is fixed at spawn (relative to the player), animation is time based. */
	private static final class FloatingLine {
		final Kind kind;
		final String text;
		final List<String> rows;
		final double born;
		final float angle;
		final float radius;
		final float height;
		final float phase;
		final float orbit;
		final float rise;
		final float hue;
		double fadeStart = Double.NaN;

		FloatingLine(Kind kind, String text, List<String> rows, double born, float angle, float radius, float height,
			float phase, float orbit, float rise, float hue) {
			this.kind = kind;
			this.text = text;
			this.rows = rows;
			this.born = born;
			this.angle = angle;
			this.radius = radius;
			this.height = height;
			this.phase = phase;
			this.orbit = orbit;
			this.rise = rise;
			this.hue = hue;
		}

		boolean dying() {
			return !Double.isNaN(fadeStart);
		}
	}

	public MusicLyrics(NyxveraClient client) {
		super("music_lyrics", Category.VISUAL);
		this.client = client;
		on(ClientTickEvent.class, event -> {
			if (!event.isPre()) {
				tick();
			}
		});
		on(WorldRenderEvent.class, this::render);
		on(WorldLeaveEvent.class, event -> resetDisplay());
	}

	@Override
	protected void onEnable() {
		media = new WindowsMediaSession();
		media.start();
	}

	@Override
	protected void onDisable() {
		if (media != null) {
			media.close();
			media = null;
		}
		if (service != null) {
			service.close();
			service = null;
		}
		serviceSources = EnumSet.noneOf(Source.class);
		previewStart = -1;
		resetDisplay();
	}

	private void resetDisplay() {
		lines.clear();
		trackKey = null;
		lastIndex = -1;
		statusKey = null;
	}

	/** Shows a short sequence of sample lines so placement, size and colors can be tuned without music. */
	public void startPreview() {
		if (!isEnabled()) {
			setEnabled(true);
		}
		fadeAll(kind -> true);
		previewStart = AnimationClock.global().now();
		previewIndex = -1;
		trackKey = null;
		lastIndex = -1;
		statusKey = null;
	}

	private LyricsService service() {
		Set<Source> wanted = EnumSet.noneOf(Source.class);
		wanted.addAll(sources.get());
		if (service == null || !wanted.equals(serviceSources)) {
			if (service != null) {
				service.close();
			}
			List<LyricsSource> list = new ArrayList<>();
			if (wanted.contains(Source.LRCLIB)) {
				list.add(new LrclibSource());
			}
			if (wanted.contains(Source.LYRICS_OVH)) {
				list.add(new LyricsOvhSource());
			}
			service = new LyricsService(list, client.config().root().resolve("lyrics"));
			serviceSources = wanted;
		}
		return service;
	}

	private void tick() {
		LocalPlayer player = Minecraft.getInstance().player;
		if (player == null) {
			return;
		}
		double now = AnimationClock.global().now();
		expire(now);
		if (previewStart >= 0) {
			tickPreview(now);
			return;
		}
		if (media == null) {
			return;
		}
		if (media.status() == MediaSource.Status.UNSUPPORTED) {
			showStatus("lyrics.unsupported");
			return;
		}
		MediaInfo info = media.current();
		if (info == null) {
			trackKey = null;
			showStatus(media.status() == MediaSource.Status.RUNNING ? "lyrics.no_media" : "lyrics.waiting");
			return;
		}
		if (!info.trackKey().equals(trackKey)) {
			trackKey = info.trackKey();
			lastIndex = -1;
			fadeAll(kind -> kind != Kind.STATUS);
			if (showTrack.get()) {
				String artist = info.artist().isEmpty() ? "" : info.artist() + " — ";
				spawn(Kind.TITLE, "♪ " + artist + info.title(), now);
			}
		}
		LyricsService.Result result = service().lookup(info);
		switch (result.state()) {
			case SEARCHING -> showStatus("lyrics.searching");
			case NOT_FOUND -> showStatus("lyrics.not_found");
			case FOUND -> {
				showStatus(null);
				if (info.playing()) {
					advance(result.lyrics(), info.positionAt(System.currentTimeMillis()) + syncOffset.get(), info.durationMillis(), now);
				}
			}
		}
	}

	private void advance(Lyrics lyrics, long position, long duration, double now) {
		int index = lyrics.lineAt(position, duration);
		if (index < 0 || index == lastIndex) {
			return;
		}
		// After a seek only the current line is shown; normal playback shows every line it passes.
		int from = index > lastIndex && index - lastIndex <= 2 ? lastIndex + 1 : index;
		for (int i = Math.max(0, from); i <= index; i++) {
			spawn(Kind.LYRIC, lyrics.lines().get(i).text(), now);
		}
		lastIndex = index;
	}

	private void tickPreview(double now) {
		int index = (int) ((now - previewStart) / PREVIEW_LINE_SECONDS);
		if (index >= PREVIEW_LINES) {
			if (lines.stream().allMatch(FloatingLine::dying)) {
				previewStart = -1;
			}
			return;
		}
		if (index != previewIndex) {
			previewIndex = index;
			spawn(index == 0 ? Kind.TITLE : Kind.LYRIC, client.i18n().tr("lyrics.preview." + (index + 1)), now);
		}
	}

	private void showStatus(String key) {
		if (java.util.Objects.equals(key, statusKey)) {
			return;
		}
		statusKey = key;
		fadeAll(kind -> kind == Kind.STATUS);
		if (key != null) {
			spawn(Kind.STATUS, client.i18n().tr(key), AnimationClock.global().now());
		}
	}

	private void fadeAll(java.util.function.Predicate<Kind> which) {
		double now = AnimationClock.global().now();
		for (FloatingLine line : lines) {
			if (!line.dying() && which.test(line.kind)) {
				line.fadeStart = now;
			}
		}
	}

	/** Starts fading lines that outlived their time or exceed the visible line limit (oldest first). */
	private void expire(double now) {
		double life = lineLife.getDouble();
		int visibleLyrics = 0;
		for (int i = lines.size() - 1; i >= 0; i--) {
			FloatingLine line = lines.get(i);
			if (line.dying() || line.kind == Kind.STATUS) {
				continue;
			}
			visibleLyrics++;
			if (visibleLyrics > maxLines.get() || now - line.born > life) {
				line.fadeStart = now;
			}
		}
		double fadeOut = fadeOutSeconds();
		lines.removeIf(line -> line.dying() && now - line.fadeStart > fadeOut);
	}

	private double fadeOutSeconds() {
		return appearTime.getDouble() * 1.3;
	}

	private void spawn(Kind kind, String text, double now) {
		LocalPlayer player = Minecraft.getInstance().player;
		if (player == null || text.isBlank()) {
			return;
		}
		if (lines.size() >= MAX_POOL) {
			lines.remove(0);
		}
		List<String> rows = List.copyOf(WorldRenderer3D.wrap(client.fonts(), Minecraft.getInstance().font, text, WRAP_WIDTH));
		boolean firstPerson = Minecraft.getInstance().options.getCameraType().isFirstPerson();
		ThreadLocalRandom random = ThreadLocalRandom.current();
		float yaw = player.getYRot();
		float eye = player.getEyeHeight();
		float radius = distance.getFloat();
		int slot = spawnCounter++;
		Placement mode = placement.get();
		if (kind == Kind.STATUS) {
			// Status lines sit calmly in front of the player, slightly above eye level.
			lines.add(new FloatingLine(kind, text, rows, now, yaw, radius * 0.9f, eye + 0.55f, 0f, 0f, 0f, 0f));
			return;
		}
		if (kind == Kind.TITLE) {
			lines.add(new FloatingLine(kind, text, rows, now, yaw, radius, eye + 0.95f, random.nextFloat() * 6.28f, 0f, 0.04f, 0f));
			return;
		}
		if (mode == Placement.DYNAMIC) {
			mode = Placement.values()[random.nextInt(3)];
		}
		float angle;
		float height;
		float lineRadius = radius;
		float orbit = 0f;
		float rise = 0.05f;
		switch (mode) {
			case LEFT_RIGHT -> {
				float side = slot % 2 == 0 ? -1f : 1f;
				angle = yaw + side * (firstPerson ? 38f : 75f);
				height = eye + (slot / 2 % 2 == 0 ? 0.15f : -0.3f);
			}
			case TOP -> {
				angle = yaw;
				lineRadius = firstPerson ? radius * 0.85f : 0f;
				height = firstPerson ? eye + 0.75f : player.getBbHeight() + 0.55f;
				rise = 0.16f;
			}
			default -> {
				// Golden-angle steps spread consecutive lines evenly; first person keeps them in the field of view.
				float step = (slot * GOLDEN_ANGLE) % 360f;
				float offset = firstPerson ? (step / 360f - 0.5f) * 130f : step;
				angle = yaw + offset;
				height = eye + new float[] {0.35f, -0.25f, 0.7f, -0.55f, 0.1f}[slot % 5];
			}
		}
		if (placement.get() == Placement.DYNAMIC) {
			angle += (random.nextFloat() - 0.5f) * 30f;
			height += (random.nextFloat() - 0.5f) * 0.4f;
			lineRadius *= 0.85f + random.nextFloat() * 0.3f;
			orbit = (random.nextBoolean() ? 1f : -1f) * (4f + random.nextFloat() * 5f);
		}
		lines.add(new FloatingLine(kind, text, rows, now, angle, lineRadius, height, random.nextFloat() * 6.28f, orbit, rise,
			(slot % 12) / 12f));
	}

	private void render(WorldRenderEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
		LocalPlayer player = minecraft.player;
		if (player == null || lines.isEmpty()) {
			return;
		}
		WorldRenderer3D.Frame frame = event.frame();
		float partial = frame.partialTick();
		double baseX = Mth.lerp(partial, player.xo, player.getX());
		double baseY = Mth.lerp(partial, player.yo, player.getY());
		double baseZ = Mth.lerp(partial, player.zo, player.getZ());
		double now = AnimationClock.global().now();
		Font font = minecraft.font;
		float appearSeconds = appearTime.getFloat();
		float fadeOut = (float) fadeOutSeconds();
		boolean motion = floatMotion.get();
		FloatingLine newestLyric = newest(Kind.LYRIC);
		for (FloatingLine line : lines) {
			float age = (float) (now - line.born);
			float in = Mth.clamp(age / appearSeconds, 0f, 1f);
			float out = line.dying() ? Mth.clamp((float) (now - line.fadeStart) / fadeOut, 0f, 1f) : 0f;
			float visibility = Easing.EASE_OUT_CUBIC.apply(in) * (1f - Easing.EASE_IN_OUT_QUAD.apply(out));
			if (visibility <= 0.01f) {
				continue;
			}
			float scale = TEXT_SCALE * size.getFloat() * (line.kind == Kind.STATUS ? 0.8f : line.kind == Kind.TITLE ? 0.9f : 1f);
			float lift = 0f;
			List<String> rows = line.rows;
			switch (appear.get()) {
				case RISE -> lift -= (1f - Easing.EASE_OUT_CUBIC.apply(in)) * 0.35f;
				case POP -> scale *= 0.55f + 0.45f * Easing.EASE_OUT_BACK.apply(in);
				case TYPEWRITER -> {
					if (in < 1f) {
						int visible = Math.max(1, Math.round(line.text.length() * in));
						rows = WorldRenderer3D.wrap(client.fonts(), font, line.text.substring(0, visible), WRAP_WIDTH);
					}
				}
				case FADE -> {
				}
			}
			lift += out * 0.3f;
			float angle = line.angle;
			if (motion) {
				lift += Mth.sin(age * 1.4f + line.phase) * 0.05f + line.rise * age;
				angle += line.orbit * age;
			}
			double radians = Math.toRadians(angle);
			double x = baseX - Math.sin(radians) * line.radius;
			double z = baseZ + Math.cos(radians) * line.radius;
			double y = baseY + line.height + lift;
			boolean current = line == newestLyric && !line.dying();
			float emphasis = line.kind == Kind.STATUS ? 0.7f : current || line.kind == Kind.TITLE ? 1f : 0.6f;
			int base = current || line.kind == Kind.TITLE ? highlight.color(line.hue) : color.color(line.hue);
			int alpha = Math.round(255 * opacity.getFloat() * visibility * emphasis);
			WorldRenderer3D.text3d(frame, client.fonts(), font, rows, x, y, z, scale, ColorUtil.withAlpha(base, alpha), depth.getFloat(), throughWalls.get());
		}
	}

	private FloatingLine newest(Kind kind) {
		for (int i = lines.size() - 1; i >= 0; i--) {
			if (lines.get(i).kind == kind) {
				return lines.get(i);
			}
		}
		return null;
	}
}
