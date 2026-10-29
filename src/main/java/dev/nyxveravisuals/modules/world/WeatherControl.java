package dev.nyxveravisuals.modules.world;

import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.ModeSetting;

/** Overrides the weather the client renders (rain, thunder, clear). Server weather is untouched. */
public final class WeatherControl extends Module {
	public enum Weather {
		CLEAR,
		RAIN,
		THUNDER
	}

	private final ModeSetting<Weather> weather = settings().add(new ModeSetting<>("weather", Weather.CLEAR));

	public WeatherControl() {
		super("weather_control", Category.WORLD);
	}

	public float rainLevel() {
		return weather.get() == Weather.CLEAR ? 0f : 1f;
	}

	public float thunderLevel() {
		return weather.get() == Weather.THUNDER ? 1f : 0f;
	}

	@Override
	public String listSuffix() {
		return weather.get().name().charAt(0) + weather.get().name().substring(1).toLowerCase(java.util.Locale.ROOT);
	}
}
