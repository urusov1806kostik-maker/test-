package dev.shadowvisuals.hud;

import net.minecraft.client.Minecraft;

import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.ui.Icon;

/** Compact "icon label value" pill used by simple readouts (FPS, ping, coordinates...). */
public abstract class InfoHudModule extends PanelHudModule {
	private final Icon icon;
	protected final BooleanSetting showLabel;

	protected InfoHudModule(String id, Icon icon, HudAnchor anchor, float offsetX, float offsetY) {
		super(id, Category.HUD, false, anchor, offsetX, offsetY);
		this.icon = icon;
		this.showLabel = settings().add(new BooleanSetting("show_label", true));
	}

	/** Current value, or {@code null} when there is nothing to show (e.g. not in a world). */
	protected abstract String value(HudContext context, Minecraft client);

	protected String label(HudContext context) {
		return context.tr("hud.label." + id());
	}

	protected int valueColor(HudContext context) {
		return context.theme().textPrimary();
	}

	@Override
	protected boolean hasContent(HudContext context) {
		return value(context, Minecraft.getInstance()) != null;
	}

	@Override
	protected void renderContent(HudContext context) {
		String value = value(context, Minecraft.getInstance());
		if (value == null) {
			value = context.editing() ? "—" : "";
		}
		float iconSize = 8;
		String label = showLabel.get() ? label(context) : null;
		float labelWidth = label == null ? 0 : width(context, label) + 4;
		float height = lineHeight(context) + PADDING * 2 - 2;
		float width = PADDING * 2 + 2 + iconSize + 4 + labelWidth + boldWidth(context, value);
		panel(context, width, height);
		float x = PADDING + 2;
		icon.draw(context.renderer(), x, (height - iconSize) / 2f, iconSize, context.theme().accent());
		x += iconSize + 4;
		float textY = height / 2f - context.renderer().fonts().visualCenter(TEXT);
		if (label != null) {
			text(context, label, x, textY, context.theme().textSecondary());
			x += labelWidth;
		}
		bold(context, value, x, textY, valueColor(context));
		setSize(width, height);
	}
}
