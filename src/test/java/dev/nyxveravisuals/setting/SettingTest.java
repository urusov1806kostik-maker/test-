package dev.nyxveravisuals.setting;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.EnumSet;
import java.util.concurrent.atomic.AtomicInteger;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import com.google.gson.JsonPrimitive;

import org.junit.jupiter.api.Test;

class SettingTest {
	enum Style { BOX, OUTLINE, GLOW }

	@Test
	void numberClampsAndSnaps() {
		NumberSetting setting = new NumberSetting("range", 4.0, 1.0, 10.0, 0.5);
		setting.set(7.26);
		assertEquals(7.5, setting.get());
		setting.set(99.0);
		assertEquals(10.0, setting.get());
		assertFalse(setting.set(Double.NaN));
		assertEquals(10.0, setting.get());
		assertEquals(1, setting.decimals());
	}

	@Test
	void numberRejectsInvalidBounds() {
		assertThrows(IllegalArgumentException.class, () -> new NumberSetting("bad", 20, 0, 10, 1));
	}

	@Test
	void listenersFireOnlyOnRealChange() {
		IntSetting setting = new IntSetting("count", 5, 0, 10);
		AtomicInteger calls = new AtomicInteger();
		setting.onChange(value -> calls.incrementAndGet());
		setting.set(5);
		setting.set(6);
		setting.set(6);
		assertEquals(1, calls.get());
	}

	@Test
	void modeParsesCaseInsensitiveAndIgnoresUnknown() {
		ModeSetting<Style> mode = new ModeSetting<>("style", Style.BOX);
		mode.load(new JsonPrimitive("outline"));
		assertEquals(Style.OUTLINE, mode.get());
		mode.load(new JsonPrimitive("does_not_exist"));
		assertEquals(Style.OUTLINE, mode.get());
		mode.cycle(1);
		assertEquals(Style.GLOW, mode.get());
		mode.cycle(1);
		assertEquals(Style.BOX, mode.get());
		assertEquals("enum.style.glow", ModeSetting.keyOf(Style.GLOW));
	}

	@Test
	void multiSelectRoundTrip() {
		MultiSelectSetting<Style> setting = new MultiSelectSetting<>("styles", Style.class, Style.BOX);
		setting.toggle(Style.GLOW);
		MultiSelectSetting<Style> copy = new MultiSelectSetting<>("styles", Style.class);
		copy.load(setting.toJson());
		assertEquals(EnumSet.of(Style.BOX, Style.GLOW), copy.get());
	}

	@Test
	void colorSerializesHexAndRainbow() {
		ColorSetting color = new ColorSetting("accent", 0xFF7C6CF2);
		color.set(color.get().withRainbow(true).withRainbowSpeed(100f));
		assertEquals(ColorSetting.MAX_RAINBOW_SPEED, color.get().rainbowSpeed());
		ColorSetting copy = new ColorSetting("accent", 0xFFFFFFFF);
		copy.load(color.toJson());
		assertEquals(0xFF7C6CF2, copy.argb());
		assertTrue(copy.isRainbow());
		ColorSetting opaque = new ColorSetting("opaque", 0x807C6CF2, false);
		assertEquals(0xFF7C6CF2, opaque.argb());
	}

	@Test
	void keybindSerialization() {
		assertEquals(Keybind.key(344), Keybind.deserialize("key:344"));
		assertEquals(Keybind.mouse(3), Keybind.deserialize(Keybind.mouse(3).serialize()));
		assertEquals(Keybind.NONE, Keybind.deserialize("none"));
		assertEquals(null, Keybind.deserialize("key:abc"));
	}

	@Test
	void stringStripsControlCharsAndLimitsLength() {
		StringSetting text = new StringSetting("name", "", 5);
		text.set("ab\ncdefg");
		assertEquals("abcde", text.get());
		text.validator(value -> !value.contains("x"));
		assertFalse(text.set("xyz"));
	}

	@Test
	void rangeKeepsOrder() {
		RangeSetting range = new RangeSetting("delay", 2, 4, 0, 10, 1);
		range.setLow(8);
		assertEquals(8, range.low());
		assertEquals(8, range.high());
		range.load(JsonParser.parseString("[9, 3]"));
		assertEquals(3, range.low());
		assertEquals(9, range.high());
	}

	@Test
	void registryRoundTripAndUnknownKeys() {
		SettingRegistry registry = new SettingRegistry("module.test");
		BooleanSetting toggle = registry.add(new BooleanSetting("enabled_thing", true));
		SettingGroup group = registry.add(new SettingGroup("advanced"));
		NumberSetting number = registry.add(group, new NumberSetting("speed", 1, 0, 5, 0.1));
		assertEquals("module.test.setting.speed", number.translationKey());
		assertEquals(group, number.parent());

		toggle.set(false);
		number.set(2.5);
		JsonObject json = registry.toJson();
		json.addProperty("removed_in_new_version", 42);

		registry.resetAll();
		assertTrue(toggle.get());
		registry.load(json);
		assertFalse(toggle.get());
		assertEquals(2.5, number.get());

		assertThrows(IllegalArgumentException.class, () -> registry.add(new BooleanSetting("speed", false)));
	}

	@Test
	void visibilityFollowsDependenciesAndParents() {
		SettingRegistry registry = new SettingRegistry("module.test");
		BooleanSetting master = registry.add(new BooleanSetting("master", false));
		SettingGroup group = registry.add(new SettingGroup("group"));
		group.dependsOn(master);
		BooleanSetting child = registry.add(group, new BooleanSetting("child", true));
		assertFalse(child.isVisible());
		master.set(true);
		assertTrue(child.isVisible());
	}

	@Test
	void invalidJsonKeepsValue() {
		BooleanSetting toggle = new BooleanSetting("flag", true);
		toggle.load(new JsonPrimitive("not a boolean"));
		assertTrue(toggle.get());
		NumberSetting number = new NumberSetting("num", 1, 0, 2, 1);
		number.load(new JsonObject());
		assertEquals(1.0, number.get());
	}
}
