package dev.nyxveravisuals.modules.hud;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.event.events.DeathEvent;
import dev.nyxveravisuals.event.events.WorldJoinEvent;
import dev.nyxveravisuals.hud.HudAnchor;
import dev.nyxveravisuals.hud.HudContext;
import dev.nyxveravisuals.hud.PanelHudModule;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.util.TimeFormat;

/** Play time in the current world, deaths this session and the current dimension. */
public final class SessionInfoHud extends PanelHudModule {
	private final NyxveraClient client;
	private int deaths;

	public SessionInfoHud(NyxveraClient client) {
		super("session_info", Category.HUD, false, HudAnchor.TOP_LEFT, 4, 78);
		this.client = client;
		client.events().subscribe(WorldJoinEvent.class, this, event -> deaths = 0);
		client.events().subscribe(DeathEvent.class, this, event -> deaths++);
	}

	@Override
	protected boolean isPrivate() {
		return true;
	}

	@Override
	protected boolean hasContent(HudContext context) {
		return client.session().inWorld();
	}

	@Override
	protected void renderContent(HudContext context) {
		Renderer2D renderer = context.renderer();
		String[] labels = {context.tr("ui.profile.session"), context.tr("hud.label.deaths"), context.tr("hud.label.dimension")};
		String dimension = client.session().dimension();
		String[] values = {
			TimeFormat.duration(client.session().sessionMillis()),
			Integer.toString(deaths),
			dimension.isEmpty() ? "—" : dimensionName(context, dimension)
		};
		float rowHeight = renderer.lineHeight(TEXT) + 2;
		float labelWidth = 0;
		float valueWidth = 0;
		for (int i = 0; i < labels.length; i++) {
			labelWidth = Math.max(labelWidth, width(context, labels[i]));
			valueWidth = Math.max(valueWidth, boldWidth(context, values[i]));
		}
		float header = rowHeight + 2;
		float width = Math.max(boldWidth(context, context.tr("hud.label.session_info")) + 16, labelWidth + valueWidth + 12) + PADDING * 2 + 2;
		float height = header + labels.length * rowHeight + PADDING * 2 - 2;
		panel(context, width, height);
		Icon.INFO.draw(renderer, PADDING + 2, PADDING, 9, context.theme().accent());
		bold(context, context.tr("hud.label.session_info"), PADDING + 14, PADDING + 4.5f - renderer.fonts().visualCenter(TEXT), context.theme().textPrimary());
		float y = PADDING + header;
		for (int i = 0; i < labels.length; i++) {
			float centerY = y + rowHeight / 2f - renderer.fonts().visualCenter(TEXT);
			text(context, labels[i], PADDING + 2, centerY, context.theme().textSecondary());
			bold(context, values[i], width - PADDING - boldWidth(context, values[i]), centerY, context.theme().textPrimary());
			y += rowHeight;
		}
		setSize(width, height);
	}

	static String dimensionName(HudContext context, String id) {
		String key = "hud.dimension." + id.substring(id.indexOf(':') + 1);
		String translated = context.i18n().find(key);
		return translated != null ? translated : id.substring(id.indexOf(':') + 1).replace('_', ' ');
	}
}
