package dev.nyxveravisuals.modules.world;

import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.IntSetting;
import dev.nyxveravisuals.setting.NumberSetting;

/**
 * Changes the time of day shown by the client only (sky, sun, light). Nothing is sent to the server and
 * the real time keeps running; disabling the module shows it again immediately.
 */
public final class TimeChanger extends Module {
	private final IntSetting time = settings().add(new IntSetting("time", 18000, 0, 23999, 100));
	private final BooleanSetting cycle = settings().add(new BooleanSetting("cycle", false));
	private final NumberSetting cycleSpeed = settings().add(new NumberSetting("cycle_speed", 1.0, 0.1, 20.0, 0.1)).dependsOn(cycle);
	private final long started = System.nanoTime();

	public TimeChanger() {
		super("time_changer", Category.WORLD);
	}

	public long dayTime(long vanilla) {
		if (cycle.get()) {
			double seconds = (System.nanoTime() - started) / 1e9;
			return (time.getInt() + (long) (seconds * 20 * cycleSpeed.getDouble())) % 24000L;
		}
		long day = vanilla - Math.floorMod(vanilla, 24000L);
		return day + time.getInt();
	}

	@Override
	public String listSuffix() {
		return Integer.toString(time.getInt());
	}
}
