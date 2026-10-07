package dev.shadowvisuals.modules.hud;

import java.time.LocalTime;
import java.time.format.DateTimeFormatter;

import net.minecraft.client.Minecraft;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.core.ClientInfo;
import dev.shadowvisuals.hud.HudAnchor;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.PanelHudModule;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.MultiSelectSetting;

/** Minimal client mark with user-selected details. Private details obey recording mode. */
public final class WatermarkHud extends PanelHudModule {
	public enum Detail {
		VERSION,
		FPS,
		PING,
		TIME,
		USERNAME,
		SERVER
	}

	private static final DateTimeFormatter CLOCK = DateTimeFormatter.ofPattern("HH:mm");

	private final ShadowClient client;
	private final MultiSelectSetting<Detail> details = settings().add(new MultiSelectSetting<>("details", Detail.class, Detail.FPS, Detail.TIME));
	private final StringBuilder line = new StringBuilder(64);

	public WatermarkHud(ShadowClient client) {
		super("watermark", Category.HUD, true, HudAnchor.TOP_LEFT, 4, 4);
		this.client = client;
	}

	@Override
	protected void renderContent(HudContext context) {
		Renderer2D renderer = context.renderer();
		Minecraft minecraft = Minecraft.getInstance();
		line.setLength(0);
		for (Detail detail : details.get()) {
			String value = switch (detail) {
				case VERSION -> "v" + ClientInfo.version();
				case FPS -> minecraft.getFps() + " fps";
				case PING -> {
					int latency = PingHud.latency(minecraft);
					yield latency < 0 ? null : latency + " ms";
				}
				case TIME -> LocalTime.now().format(CLOCK);
				case USERNAME -> context.privacy().hideName() ? null : minecraft.getUser().getName();
				case SERVER -> {
					String address = client.session().serverAddress(minecraft);
					yield address == null || context.privacy().hideServer() ? null : address;
				}
			};
			if (value != null) {
				line.append(line.isEmpty() ? "" : "  ·  ").append(value);
			}
		}
		String brand = "Shadow";
		String brandRest = " Visuals";
		float dot = 7;
		float brandWidth = renderer.textWidth(brand, TEXT, FontManager.Weight.SEMIBOLD) + renderer.textWidth(brandRest, TEXT);
		String info = line.toString();
		float infoWidth = info.isEmpty() ? 0 : width(context, info) + 12;
		float height = lineHeight(context) + PADDING * 2 - 2;
		float width = PADDING * 2 + 2 + dot + 5 + brandWidth + infoWidth;
		panel(context, width, height);
		float x = PADDING + 2;
		renderer.gradientHorizontal(x, (height - dot) / 2f, dot, dot, 2.5f, context.theme().accent(), context.theme().accentSecondary());
		x += dot + 5;
		float textY = height / 2f - renderer.fonts().visualCenter(TEXT);
		bold(context, brand, x, textY, context.theme().textPrimary());
		x += renderer.textWidth(brand, TEXT, FontManager.Weight.SEMIBOLD);
		text(context, brandRest, x, textY, context.theme().textSecondary());
		x += renderer.textWidth(brandRest, TEXT);
		if (!info.isEmpty()) {
			renderer.rect(x + 5.5f, height * 0.28f, 1, height * 0.44f, context.theme().border());
			text(context, info, x + 12, textY, context.theme().textSecondary());
		}
		setSize(width, height);
	}
}
