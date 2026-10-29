package dev.nyxveravisuals.modules.iface;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.MutableComponent;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * Display-only chat styling: optional timestamps and a themed background. Messages you send and receive are
 * never modified on the network; the timestamp is added only to the locally displayed line.
 */
public final class ChatVisuals extends Module {
	public enum TimeFormat {
		HOURS_MINUTES,
		WITH_SECONDS
	}

	private static final DateTimeFormatter SHORT = DateTimeFormatter.ofPattern("HH:mm");
	private static final DateTimeFormatter LONG = DateTimeFormatter.ofPattern("HH:mm:ss");

	private final NyxveraClient client;
	private final BooleanSetting timestamps = settings().add(new BooleanSetting("timestamps", true));
	private final ModeSetting<TimeFormat> format = settings().add(new ModeSetting<>("time_format", TimeFormat.HOURS_MINUTES)).dependsOn(timestamps);
	private final ColorSetting timestampColor = settings().add(new ColorSetting("timestamp_color", 0xFF8D93A5, false)).dependsOn(timestamps);
	private final BooleanSetting themedBackground = settings().add(new BooleanSetting("themed_background", true));
	private final NumberSetting opacity = settings().add(new NumberSetting("background_opacity", 1.0, 0.0, 2.0, 0.05).suffix("x"));

	public ChatVisuals(NyxveraClient client) {
		super("chat_visuals", Category.INTERFACE);
		this.client = client;
	}

	public Component decorate(Component message) {
		if (!timestamps.get()) {
			return message;
		}
		String time = LocalTime.now().format(format.get() == TimeFormat.WITH_SECONDS ? LONG : SHORT);
		MutableComponent prefix = Component.literal("[" + time + "] ").withColor(timestampColor.color() & 0xFFFFFF);
		return prefix.append(message);
	}

	/** Recolors vanilla's black chat backgrounds; other fills (scroll bar) pass through. */
	public int background(int argb) {
		if ((argb & 0xFFFFFF) != 0) {
			return argb;
		}
		int alpha = Math.min(255, Math.round(ColorUtil.alpha(argb) * opacity.getFloat()));
		int base = themedBackground.get() ? client.theme().panel() : 0xFF000000;
		return ColorUtil.withAlpha(base, alpha);
	}
}
