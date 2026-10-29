package dev.nyxveravisuals.ui.screen;

import org.lwjgl.glfw.GLFW;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.setting.Keybind;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.clickgui.ConfigPage;
import dev.nyxveravisuals.ui.clickgui.ModuleSettingsPanel;
import dev.nyxveravisuals.ui.clickgui.ModulesPage;
import dev.nyxveravisuals.ui.clickgui.Page;
import dev.nyxveravisuals.ui.clickgui.ProfileBadge;
import dev.nyxveravisuals.ui.clickgui.SettingsPage;
import dev.nyxveravisuals.ui.clickgui.Sidebar;
import dev.nyxveravisuals.ui.component.Button;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.component.TextField;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * The NyxveraVisuals ClickGUI: sidebar navigation, a header with search, the active page and the module
 * settings panel. Layers, from bottom to top: background, panel, page content, settings panel, overlays,
 * tooltips.
 */
public final class ClickGuiScreen extends NyxveraScreen {
	private static final float PANEL_PADDING = 10;

	private final Sidebar sidebar;
	private final ModulesPage modulesPage;
	private final ConfigPage configPage;
	private final SettingsPage settingsPage;
	private final ModuleSettingsPanel settingsPanel;
	private final TextField search;
	private final Button hudEditor;
	private Page page;
	private String query = "";
	private float panelX;
	private float panelY;

	public ClickGuiScreen(NyxveraClient client) {
		super(client, "screen.clickgui");
		this.page = Page.byName(client.preferences().lastPage());
		this.settingsPanel = new ModuleSettingsPanel(client);
		this.modulesPage = new ModulesPage(client, module -> settingsPanel.open(context, module));
		this.configPage = new ConfigPage(client);
		this.settingsPage = new SettingsPage(client);
		this.sidebar = new Sidebar(page, this::selectPage, new ProfileBadge(client));
		this.search = new TextField(40).placeholder("ui.search").icon(Icon.SEARCH).onChange(value -> {
			query = value.strip();
			refreshModules();
			modulesPage.resetScroll();
		});
		this.hudEditor = new Button("ui.hud_editor", Icon.MOVE, Button.Style.SECONDARY, () -> client.screens().openHudEditor());
		refreshModules();
	}

	public void selectPage(Page next) {
		page = next;
		sidebar.select(next);
		query = "";
		search.setText("");
		context.clearFocus();
		settingsPanel.close();
		configPage.refresh();
		client.preferences().setLastPage(next.name());
		client.config().markDirty(client.preferences());
		refreshModules();
		modulesPage.resetScroll();
	}

	/** Shows the page of {@code module}'s category with the module's settings panel open. */
	public void openModuleSettings(Module module) {
		selectPage(Page.of(module.category()));
		settingsPanel.open(context, module);
	}

	private boolean showsModules() {
		return !query.isEmpty() || (page != Page.CONFIG && page != Page.SETTINGS);
	}

	private void refreshModules() {
		if (!query.isEmpty()) {
			modulesPage.show(client.modules().search(query, client.i18n()::tr), "ui.empty.search", Icon.SEARCH);
		} else if (page == Page.FAVORITES) {
			modulesPage.show(client.modules().favorites(), "ui.empty.favorites", Icon.STAR);
		} else if (page.category() != null) {
			modulesPage.show(client.modules().inCategory(page.category()), "ui.empty.category", Icon.LAYOUT);
		}
	}

	@Override
	protected float designWidth() {
		return DesignTokens.PANEL_MAX_WIDTH;
	}

	@Override
	protected float designHeight() {
		return DesignTokens.PANEL_MAX_HEIGHT;
	}

	@Override
	protected void renderContent(UiContext ui, float mouseX, float mouseY, float open) {
		Renderer2D renderer = ui.renderer();
		ThemeManager theme = ui.theme();
		float panelWidth = DesignTokens.PANEL_MAX_WIDTH;
		float panelHeight = DesignTokens.PANEL_MAX_HEIGHT;
		panelX = (ui.width() - panelWidth) / 2f;
		panelY = (ui.height() - panelHeight) / 2f;

		renderer.pushAlpha(open);
		renderer.push();
		renderer.scaleAround(0.94f + 0.06f * open, panelX + panelWidth / 2f, panelY + panelHeight / 2f);
		renderer.translate(0, (1 - open) * 8);

		renderer.shadow(panelX, panelY + 4, panelWidth, panelHeight, DesignTokens.RADIUS_XL, 30, ColorUtil.withAlpha(0, 150));
		renderer.gradientVertical(panelX, panelY, panelWidth, panelHeight, DesignTokens.RADIUS_XL, theme.panel(), ColorUtil.shade(theme.panel(), -0.06f));
		renderer.outline(panelX, panelY, panelWidth, panelHeight, DesignTokens.RADIUS_XL, 1, theme.border());

		sidebar.setBounds(panelX, panelY, DesignTokens.SIDEBAR_WIDTH, panelHeight);
		sidebar.render(ui, mouseX, mouseY);

		float contentX = panelX + DesignTokens.SIDEBAR_WIDTH + PANEL_PADDING + 4;
		float contentWidth = panelX + panelWidth - PANEL_PADDING - contentX;
		float headerY = panelY + PANEL_PADDING;
		drawHeader(ui, renderer, theme, contentX, headerY, contentWidth, mouseX, mouseY);

		float bodyY = headerY + DesignTokens.HEADER_HEIGHT + DesignTokens.SPACE_S;
		float bodyHeight = panelY + panelHeight - PANEL_PADDING - bodyY;
		boolean panelOpen = settingsPanel.isShowing();
		float bodyMouseX = panelOpen && settingsPanel.contains(mouseX, mouseY) ? -1e6f : mouseX;
		Component body = body();
		body.setBounds(contentX, bodyY, contentWidth, bodyHeight);
		renderer.pushClip(contentX - 4, bodyY - 2, contentWidth + 8, bodyHeight + 4);
		body.render(ui, settingsPanel.isOpen() ? -1e6f : bodyMouseX, mouseY);
		renderer.popClip();

		float panelWidthSettings = Math.min(DesignTokens.SETTINGS_PANEL_WIDTH + 30, contentWidth * 0.62f);
		settingsPanel.setBounds(panelX + panelWidth - panelWidthSettings - 6, panelY + 6, panelWidthSettings, panelHeight - 12);
		if (panelOpen) {
			renderer.pushClip(panelX, panelY, panelWidth, panelHeight);
			settingsPanel.render(ui, mouseX, mouseY);
			renderer.popClip();
		}
		renderer.pop();
		renderer.popAlpha();
	}

	private Component body() {
		if (!showsModules()) {
			return page == Page.CONFIG ? configPage : settingsPage;
		}
		return modulesPage;
	}

	private void drawHeader(UiContext ui, Renderer2D renderer, ThemeManager theme, float x, float y, float width, float mouseX, float mouseY) {
		float titleSize = ui.text(DesignTokens.FONT_HEADING);
		String title = query.isEmpty() ? ui.tr(page.translationKey()) : ui.tr("ui.search_results");
		renderer.text(title, x, y + 2, titleSize, theme.textPrimary(), FontManager.Weight.SEMIBOLD, false);
		String subtitle;
		if (showsModules()) {
			int count = modulesPage.count();
			subtitle = ui.tr(count == 1 ? "ui.modules_count_one" : "ui.modules_count", count);
		} else {
			subtitle = ui.tr(page == Page.CONFIG ? "ui.config.subtitle" : "ui.settings.subtitle");
		}
		renderer.text(subtitle, x, y + 2 + titleSize * 1.25f, ui.text(DesignTokens.FONT_CAPTION), theme.textSecondary());

		float searchWidth = Math.min(150, width * 0.38f);
		search.setBounds(x + width - searchWidth, y + 4, searchWidth, 18);
		search.render(ui, mouseX, mouseY);
		if (page == Page.HUD && query.isEmpty()) {
			float buttonWidth = hudEditor.preferredWidth(ui);
			hudEditor.setBounds(search.x() - buttonWidth - 6, y + 4, buttonWidth, 18);
			hudEditor.render(ui, mouseX, mouseY);
		} else {
			hudEditor.setBounds(-1e6f, -1e6f, 0, 0);
		}
		renderer.rect(x, y + DesignTokens.HEADER_HEIGHT, width, 1, theme.border());
	}

	// ------------------------------------------------------------------ input

	@Override
	protected boolean onMouseClicked(float mouseX, float mouseY, int button) {
		if (settingsPanel.isOpen()) {
			if (settingsPanel.mouseClicked(context, mouseX, mouseY, button)) {
				return true;
			}
		}
		if (search.mouseClicked(context, mouseX, mouseY, button) || hudEditor.mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		if (sidebar.mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		return body().mouseClicked(context, mouseX, mouseY, button);
	}

	@Override
	protected boolean onMouseReleased(float mouseX, float mouseY, int button) {
		settingsPanel.mouseReleased(context, mouseX, mouseY, button);
		return body().mouseReleased(context, mouseX, mouseY, button);
	}

	@Override
	protected boolean onMouseDragged(float mouseX, float mouseY, int button) {
		if (settingsPanel.isOpen() && settingsPanel.mouseDragged(context, mouseX, mouseY, button)) {
			return true;
		}
		return body().mouseDragged(context, mouseX, mouseY, button);
	}

	@Override
	protected boolean onMouseScrolled(float mouseX, float mouseY, double amount) {
		if (settingsPanel.isOpen()) {
			settingsPanel.mouseScrolled(context, mouseX, mouseY, amount);
			return true;
		}
		return body().mouseScrolled(context, mouseX, mouseY, amount);
	}

	@Override
	protected boolean onKeyPressed(int key, int scancode, int modifiers) {
		boolean control = (modifiers & (GLFW.GLFW_MOD_CONTROL | GLFW.GLFW_MOD_SUPER)) != 0;
		if (control && key == GLFW.GLFW_KEY_F) {
			context.focus(search);
			return true;
		}
		if (client.settings().guiKey.get().matches(Keybind.Device.KEYBOARD, key)) {
			onClose();
			return true;
		}
		if (settingsPanel.isOpen() && settingsPanel.keyPressed(context, key, scancode, modifiers)) {
			return true;
		}
		return body().keyPressed(context, key, scancode, modifiers);
	}

	@Override
	protected boolean onCharTyped(int codePoint) {
		if (!Character.isISOControl(codePoint) && !Character.isWhitespace(codePoint) && context.focused() == null && !settingsPanel.isOpen()
			&& showsModules()) {
			context.focus(search);
			return search.charTyped(context, codePoint);
		}
		return false;
	}

	@Override
	protected boolean onEscape() {
		if (settingsPanel.isOpen()) {
			settingsPanel.close();
			return true;
		}
		if (!query.isEmpty()) {
			search.setText("");
			query = "";
			refreshModules();
			return true;
		}
		return false;
	}
}
