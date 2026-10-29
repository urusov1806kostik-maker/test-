package dev.nyxveravisuals.ui.clickgui;

import java.util.ArrayList;
import java.util.List;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.notification.NotificationManager;
import dev.nyxveravisuals.setting.ActionSetting;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.component.ScrollPanel;
import dev.nyxveravisuals.ui.component.Tabs;
import dev.nyxveravisuals.ui.settings.SectionLabel;
import dev.nyxveravisuals.ui.settings.SettingRow;
import dev.nyxveravisuals.ui.settings.SettingsList;

/** Client settings (interface, accessibility, notifications), theme editor and reset actions. */
public final class SettingsPage extends Component {
	private final NyxveraClient client;
	private final Tabs tabs;
	private final ScrollPanel list = new ScrollPanel(ScrollPanel.stack(2)).padding(2);
	private int tab;
	private boolean dirty = true;

	public SettingsPage(NyxveraClient client) {
		this.client = client;
		this.tabs = new Tabs(List.of("ui.settings.general", "ui.settings.theme"), index -> {
			tab = index;
			dirty = true;
			list.resetScroll();
		});
	}

	private void rebuild(UiContext context) {
		List<Component> rows = new ArrayList<>();
		if (tab == 0) {
			rows.addAll(SettingsList.build(context, client.settings().settings(), node -> true));
			rows.add(new SectionLabel("ui.settings.actions"));
			rows.add(new SettingRow(context, new ActionSetting("open_hud_editor", () -> client.screens().openHudEditor()), () -> true, 0));
			rows.add(new SettingRow(context, new ActionSetting("reset_hud", true, () -> {
				client.hud().resetPositions();
				done("ui.settings.hud_reset");
			}), () -> true, 0));
			rows.add(new SettingRow(context, new ActionSetting("reset_client", true, () -> {
				client.resetEverything();
				done("ui.settings.client_reset");
			}), () -> true, 0));
		} else {
			rows.addAll(SettingsList.build(context, client.theme().settings(), node -> true));
			rows.add(new SectionLabel("ui.settings.actions"));
			rows.add(new SettingRow(context, new ActionSetting("reset_theme", true, () -> {
				client.theme().reset();
				done("ui.settings.theme_reset");
			}), () -> true, 0));
		}
		list.setChildren(rows);
	}

	private void done(String key) {
		client.notifications().push(NotificationManager.Type.SUCCESS, client.i18n().tr("page.settings"), client.i18n().tr(key));
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		if (dirty) {
			rebuild(context);
			dirty = false;
		}
		tabs.setBounds(x, y, Math.min(width, 200), DesignTokens.CONTROL_HEIGHT + 4);
		tabs.render(context, mouseX, mouseY);
		float top = y + tabs.height() + DesignTokens.SPACE_M;
		float listWidth = Math.min(width, 360);
		list.setBounds(x, top, listWidth, y + height - top);
		list.render(context, mouseX, mouseY);
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		return tabs.mouseClicked(context, mouseX, mouseY, button) || list.mouseClicked(context, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseScrolled(UiContext context, float mouseX, float mouseY, double amount) {
		return list.mouseScrolled(context, mouseX, mouseY, amount);
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		return list.mouseDragged(context, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		return list.mouseReleased(context, mouseX, mouseY, button);
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		return list.keyPressed(context, key, scancode, modifiers);
	}
}
