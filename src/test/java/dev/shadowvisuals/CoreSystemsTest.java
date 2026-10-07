package dev.shadowvisuals;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;

import org.junit.jupiter.api.Test;

import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.AnimationClock;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.event.Cancellable;
import dev.shadowvisuals.event.EventBus;
import dev.shadowvisuals.event.Priority;
import dev.shadowvisuals.i18n.Localization;
import dev.shadowvisuals.notification.NotificationManager;
import dev.shadowvisuals.util.ColorUtil;
import dev.shadowvisuals.waypoint.Waypoint;
import dev.shadowvisuals.waypoint.WaypointManager;

class CoreSystemsTest {
	static final class Hit implements Cancellable {
		boolean cancelled;

		@Override
		public boolean isCancelled() {
			return cancelled;
		}

		@Override
		public void cancel() {
			cancelled = true;
		}
	}

	@Test
	void eventPriorityCancellationAndMonitor() {
		EventBus bus = new EventBus();
		List<String> order = new ArrayList<>();
		bus.subscribe(Hit.class, "low", Priority.LOW, hit -> order.add("low"));
		bus.subscribe(Hit.class, "high", Priority.HIGH, hit -> {
			order.add("high");
			hit.cancel();
		});
		bus.subscribe(Hit.class, "monitor", Priority.MONITOR, hit -> order.add("monitor"));
		var sub = bus.subscribe(Hit.class, "normal", hit -> order.add("normal"));
		assertTrue(bus.post(new Hit()).isCancelled());
		assertEquals(List.of("high"), order);
		sub.unsubscribe();
		sub.unsubscribe();
	}

	@Test
	void animationsAreTimeBasedNotFrameBased() {
		AtomicLong nanos = new AtomicLong();
		AnimationClock clock = new AnimationClock(nanos::get);
		Animation animation = new Animation(clock, 0f, 0.2f, Easing.LINEAR);
		animation.animateTo(1f);

		// 60 FPS for 100 ms vs. 300 FPS for 100 ms must reach the same value.
		for (int i = 0; i < 6; i++) {
			nanos.addAndGet(16_666_667L);
			clock.frame();
		}
		float at60 = animation.value();
		AtomicLong nanos2 = new AtomicLong();
		AnimationClock clock2 = new AnimationClock(nanos2::get);
		Animation animation2 = new Animation(clock2, 0f, 0.2f, Easing.LINEAR);
		animation2.animateTo(1f);
		for (int i = 0; i < 30; i++) {
			nanos2.addAndGet(3_333_333L);
			clock2.frame();
		}
		assertEquals(at60, animation2.value(), 0.01f);
		assertEquals(0.5f, at60, 0.01f);

		clock.setMode(AnimationClock.Mode.OFF);
		assertEquals(1f, animation.value());
	}

	@Test
	void smoothValueConvergesIndependentOfFrameRate() {
		AtomicLong a = new AtomicLong();
		AtomicLong b = new AtomicLong();
		AnimationClock fast = new AnimationClock(a::get);
		AnimationClock slow = new AnimationClock(b::get);
		SmoothValue v1 = new SmoothValue(fast, 0f, 10f);
		SmoothValue v2 = new SmoothValue(slow, 0f, 10f);
		v1.setTarget(1f);
		v2.setTarget(1f);
		for (int i = 0; i < 300; i++) {
			a.addAndGet(1_000_000L);
			fast.frame();
			v1.get();
		}
		for (int i = 0; i < 30; i++) {
			b.addAndGet(10_000_000L);
			slow.frame();
			v2.get();
		}
		assertEquals(v1.get(), v2.get(), 0.001f);
	}

	@Test
	void colorConversions() {
		float[] hsv = ColorUtil.toHsv(0xFFFF0000, new float[3]);
		assertEquals(0f, hsv[0], 1e-4);
		assertEquals(0xFF00FF00, ColorUtil.fromHsv(1f / 3f, 1f, 1f, 255));
		assertEquals(0xFF112233, ColorUtil.parseHex("#123"));
		assertEquals(0x80FFFFFF, ColorUtil.parseHex("80ffffff"));
		assertNull(ColorUtil.parseHex("#12345"));
		assertEquals(0xFF808080, ColorUtil.lerp(0xFF000000, 0xFFFFFFFF, 0.5f));
		assertEquals(0x80123456, ColorUtil.fade(0xFF123456, 128f / 255f));
	}

	@Test
	void localizationFallsBackToEnglishAndHumanizes() {
		Localization localization = new Localization(path -> {
			String json = switch (path) {
				case "/assets/shadowvisuals/i18n/en_us.json" -> "{\"category\":{\"visual\":\"Visual\"},\"hello\":\"Hello {0}\"}";
				case "/assets/shadowvisuals/i18n/ru_ru.json" -> "{\"category\":{\"visual\":\"Визуал\"}}";
				default -> null;
			};
			return json == null ? null : new ByteArrayInputStream(json.getBytes(StandardCharsets.UTF_8));
		});
		localization.select(Localization.Language.AUTO, "ru_RU");
		assertEquals("Визуал", localization.tr("category.visual"));
		assertEquals("Hello Steve", localization.tr("hello", "Steve"));
		assertEquals("Max distance", localization.tr("module.esp.setting.max_distance"));
		localization.select(Localization.Language.UKRAINIAN, null);
		assertEquals("en_us", localization.languageCode());
	}

	@Test
	void deathPointsAreCapped() {
		WaypointManager manager = new WaypointManager();
		for (int i = 0; i < 5; i++) {
			manager.addDeathPoint("Death", i, 64, 0, "minecraft:overworld", "server", 0xFFFF0000, 2);
		}
		manager.addDeathPoint("Death", 0, 64, 0, "minecraft:overworld", "other", 0xFFFF0000, 2);
		long deaths = manager.inWorld("server").stream().filter(w -> w.kind() == Waypoint.Kind.DEATH).count();
		assertEquals(2, deaths);
		assertEquals(2, manager.visibleIn("server", "minecraft:overworld").size());
		assertEquals(0, manager.visibleIn("server", "minecraft:the_nether").size());

		WaypointManager copy = new WaypointManager();
		copy.load(manager.save());
		assertEquals(3, copy.all().size());
	}

	@Test
	void notificationsAreBoundedAndExpire() {
		AtomicLong nanos = new AtomicLong();
		AnimationClock clock = new AnimationClock(nanos::get);
		NotificationManager manager = new NotificationManager(clock);
		for (int i = 0; i < 20; i++) {
			manager.push(NotificationManager.Type.INFO, "Title " + i, "Message");
			manager.update();
		}
		assertTrue(manager.active().size() <= 20);
		nanos.addAndGet(1_000_000_000L);
		clock.frame();
		manager.update();
		assertTrue(manager.active().size() <= NotificationManager.MAX_ACTIVE);

		manager.push(NotificationManager.Type.INFO, "Same", "Text");
		manager.push(NotificationManager.Type.INFO, "Same", "Text");
		assertEquals(1, manager.active().stream().filter(n -> n.title().equals("Same")).count());

		for (int i = 0; i < 20; i++) {
			nanos.addAndGet(1_000_000_000L);
			clock.frame();
			manager.update();
		}
		assertTrue(manager.active().isEmpty());
		assertFalse(manager.active().iterator().hasNext());
	}
}
