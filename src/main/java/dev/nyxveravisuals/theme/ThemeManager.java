package dev.nyxveravisuals.theme;

import com.google.gson.JsonObject;

import dev.nyxveravisuals.setting.ColorSetting;
import dev.nyxveravisuals.setting.Configurable;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.SettingRegistry;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * The active color theme. Every color is a regular {@link ColorSetting}, so changes apply live and persist
 * with the profile. Choosing a preset rewrites the colors; editing a color afterwards keeps the preset name
 * as the starting point. Derived shades (hover, pressed, muted accent) are computed here, once, so all
 * windows stay visually consistent.
 */
public final class ThemeManager implements Configurable {
	public enum Preset {
		NYXVERA(0xFF8B7CF6, 0xFF5B8CFF, 0xFF0C0D12, 0xFF12131A, 0xFF181A23, 0xFF262935, 0xFFE9EAF0, 0xFF8D93A5),
		MIDNIGHT(0xFF5B8CFF, 0xFF44C2FF, 0xFF0A0D14, 0xFF10141E, 0xFF161B27, 0xFF232A3A, 0xFFE6EBF5, 0xFF8792A8),
		AMETHYST(0xFFB07CF6, 0xFFF67CC8, 0xFF0F0B14, 0xFF16111D, 0xFF1D1726, 0xFF2D2438, 0xFFF0EAF5, 0xFF9A8EAA),
		GRAPHITE(0xFFA0A8BA, 0xFF7C8496, 0xFF0D0D0F, 0xFF141416, 0xFF1A1A1E, 0xFF2A2A30, 0xFFEDEDF0, 0xFF8E8E98),
		EMERALD(0xFF3DD68C, 0xFF35B8C9, 0xFF0A0F0D, 0xFF101713, 0xFF151E19, 0xFF22302A, 0xFFE8F2EC, 0xFF86998F);

		final int accent;
		final int accentSecondary;
		final int background;
		final int panel;
		final int card;
		final int border;
		final int textPrimary;
		final int textSecondary;

		Preset(int accent, int accentSecondary, int background, int panel, int card, int border, int textPrimary, int textSecondary) {
			this.accent = accent;
			this.accentSecondary = accentSecondary;
			this.background = background;
			this.panel = panel;
			this.card = card;
			this.border = border;
			this.textPrimary = textPrimary;
			this.textSecondary = textSecondary;
		}
	}

	private final SettingRegistry settings = new SettingRegistry("theme");
	private final ModeSetting<Preset> preset = settings.add(new ModeSetting<>("preset", Preset.NYXVERA));
	private final ColorSetting accent = settings.add(new ColorSetting("accent", Preset.NYXVERA.accent, false));
	private final ColorSetting accentSecondary = settings.add(new ColorSetting("accent_secondary", Preset.NYXVERA.accentSecondary, false));
	private final ColorSetting background = settings.add(new ColorSetting("background", Preset.NYXVERA.background, false));
	private final ColorSetting panel = settings.add(new ColorSetting("panel", Preset.NYXVERA.panel, false));
	private final ColorSetting card = settings.add(new ColorSetting("card", Preset.NYXVERA.card, false));
	private final ColorSetting border = settings.add(new ColorSetting("border", Preset.NYXVERA.border, false));
	private final ColorSetting textPrimary = settings.add(new ColorSetting("text_primary", Preset.NYXVERA.textPrimary, false));
	private final ColorSetting textSecondary = settings.add(new ColorSetting("text_secondary", Preset.NYXVERA.textSecondary, false));
	private final ColorSetting enabled = settings.add(new ColorSetting("enabled", Preset.NYXVERA.accent, false));
	private final ColorSetting success = settings.add(new ColorSetting("success", 0xFF3DD68C, false));
	private final ColorSetting warning = settings.add(new ColorSetting("warning", 0xFFF5B544, false));
	private final ColorSetting error = settings.add(new ColorSetting("error", 0xFFF2555A, false));

	private boolean loading;
	private boolean highContrast;

	public ThemeManager() {
		preset.onChange(value -> {
			if (!loading) {
				applyPreset(value);
			}
		});
	}

	@Override
	public SettingRegistry settings() {
		return settings;
	}

	public ModeSetting<Preset> preset() {
		return preset;
	}

	public void applyPreset(Preset value) {
		accent.setArgb(value.accent);
		accentSecondary.setArgb(value.accentSecondary);
		background.setArgb(value.background);
		panel.setArgb(value.panel);
		card.setArgb(value.card);
		border.setArgb(value.border);
		textPrimary.setArgb(value.textPrimary);
		textSecondary.setArgb(value.textSecondary);
		enabled.setArgb(value.accent);
	}

	public void reset() {
		loading = true;
		try {
			settings.resetAll();
		} finally {
			loading = false;
		}
	}

	public JsonObject toJson() {
		return settings.toJson();
	}

	/** Loads colors without letting the stored preset overwrite them. */
	public void load(JsonObject json) {
		loading = true;
		try {
			settings.resetAll();
			settings.load(json);
		} finally {
			loading = false;
		}
	}

	public void setHighContrast(boolean value) {
		this.highContrast = value;
	}

	public boolean highContrast() {
		return highContrast;
	}

	public int accent() {
		return accent.color();
	}

	/** Accent with a hue offset, used for flowing gradients when rainbow is enabled. */
	public int accent(float offset) {
		return accent.color(offset);
	}

	public int accentSecondary() {
		return accentSecondary.color(0.15f);
	}

	public int background() {
		return background.color();
	}

	public int panel() {
		return panel.color();
	}

	public int card() {
		return card.color();
	}

	public int cardHover() {
		return ColorUtil.shade(card.color(), 0.035f);
	}

	public int cardPressed() {
		return ColorUtil.shade(card.color(), 0.07f);
	}

	public int border() {
		return highContrast ? ColorUtil.shade(border.color(), 0.18f) : border.color();
	}

	public int textPrimary() {
		return highContrast ? 0xFFFFFFFF : textPrimary.color();
	}

	public int textSecondary() {
		return highContrast ? ColorUtil.shade(textSecondary.color(), 0.35f) : textSecondary.color();
	}

	public int textDisabled() {
		return ColorUtil.lerp(textSecondary(), card.color(), 0.45f);
	}

	public int enabled() {
		return enabled.color();
	}

	public int success() {
		return success.color();
	}

	public int warning() {
		return warning.color();
	}

	public int error() {
		return error.color();
	}

	/** Translucent accent for selection backgrounds and focus rings. */
	public int accentMuted(int alpha) {
		return ColorUtil.withAlpha(accent(), alpha);
	}

	public int shadow() {
		return 0x8C000000;
	}
}
