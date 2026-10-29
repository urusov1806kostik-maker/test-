package dev.nyxveravisuals.ui.screen;

import java.util.ArrayList;
import java.util.List;

import org.lwjgl.glfw.GLFW;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.hud.HudModule;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Button;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.component.ScrollPanel;
import dev.nyxveravisuals.ui.component.Toggle;
import dev.nyxveravisuals.ui.overlay.ContextMenu;
import dev.nyxveravisuals.ui.overlay.Dialog;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * Drag-and-drop HUD layout editor. Elements snap to screen edges, the center lines and other elements;
 * the wheel scales the hovered element, arrow keys nudge the selection and nothing can be dropped off
 * screen. Works in GUI units, so positions match the in-game HUD exactly.
 */
public final class HudEditorScreen extends NyxveraScreen {
	private static final float SNAP = 4f;
	private static final float PANEL_WIDTH = 132;

	private final Button done;
	private final Button resetAll;
	private final Button snapping;
	private final ScrollPanel elementList = new ScrollPanel(ScrollPanel.stack(2)).padding(2);
	private HudModule selected;
	private HudModule dragging;
	private float dragOffsetX;
	private float dragOffsetY;
	private boolean snapEnabled = true;
	private float guideX = Float.NaN;
	private float guideY = Float.NaN;

	public HudEditorScreen(NyxveraClient client) {
		super(client, "screen.hud_editor");
		this.done = new Button("ui.done", Icon.CHECK, Button.Style.PRIMARY, this::onClose);
		this.resetAll = new Button("ui.hud.reset_all", Icon.RESET, Button.Style.SECONDARY, () ->
			Dialog.confirm(context, "ui.hud.reset_all", context.tr("ui.hud.reset_all_confirm"), "ui.reset", true, client.hud()::resetPositions));
		this.snapping = new Button("ui.hud.snapping", Icon.MOVE, Button.Style.SECONDARY, () -> snapEnabled = !snapEnabled);
		List<Component> rows = new ArrayList<>();
		for (HudModule module : client.hud().elements()) {
			rows.add(new ElementRow(module));
		}
		elementList.setChildren(rows);
	}

	@Override
	protected float uiScale() {
		return 1f;
	}

	@Override
	protected float designWidth() {
		return width;
	}

	@Override
	protected float designHeight() {
		return height;
	}

	@Override
	protected boolean dimsBackground() {
		return false;
	}

	@Override
	protected void renderContent(UiContext ui, float mouseX, float mouseY, float open) {
		Renderer2D renderer = ui.renderer();
		ThemeManager theme = ui.theme();
		renderer.pushAlpha(open);
		renderer.rect(0, 0, ui.width(), ui.height(), 0x30000000);
		if (!Float.isNaN(guideX)) {
			renderer.rect(guideX - 0.5f, 0, 1, ui.height(), theme.accentMuted(170));
		}
		if (!Float.isNaN(guideY)) {
			renderer.rect(0, guideY - 0.5f, ui.width(), 1, theme.accentMuted(170));
		}
		HudModule hovered = dragging != null ? dragging : client.hud().elementAt(mouseX, mouseY);
		for (HudModule element : client.hud().elements()) {
			if (!element.isEnabled() || !element.isShowing()) {
				continue;
			}
			float x = element.lastX();
			float y = element.lastY();
			float w = element.scaledWidth();
			float h = element.scaledHeight();
			boolean active = element == hovered || element == selected;
			renderer.rounded(x - 2, y - 2, w + 4, h + 4, DesignTokens.RADIUS_S, ColorUtil.withAlpha(theme.accent(), active ? 34 : 14));
			renderer.outline(x - 2, y - 2, w + 4, h + 4, DesignTokens.RADIUS_S, 1, ColorUtil.withAlpha(theme.accent(), active ? 210 : 90));
			if (active) {
				String label = ui.tr(element.nameKey()) + "  " + Math.round(element.scale() * 100) + "%";
				float size = DesignTokens.FONT_CAPTION;
				float labelWidth = renderer.textWidth(label, size, FontManager.Weight.SEMIBOLD) + 8;
				float labelY = y - 14 < 2 ? y + h + 4 : y - 14;
				renderer.rounded(x - 2, labelY, labelWidth, 11, 3, theme.accent());
				renderer.textMiddle(label, x + 2, labelY + 5.5f, size, ColorUtil.readableTextOn(theme.accent()), FontManager.Weight.SEMIBOLD,
					Renderer2D.Align.LEFT);
			}
		}

		float toolbarWidth = 270;
		float toolbarX = (ui.width() - toolbarWidth) / 2f;
		float toolbarY = 8;
		renderer.surface(toolbarX, toolbarY, toolbarWidth, 26, DesignTokens.RADIUS_L, ColorUtil.withAlpha(theme.panel(), 235), theme.border(), theme.shadow(), 12);
		renderer.textMiddle(ui.tr("ui.hud.hint"), toolbarX + 10, toolbarY + 13, DesignTokens.FONT_CAPTION, theme.textSecondary());
		done.setBounds(toolbarX + toolbarWidth - 58, toolbarY + 5, 52, 16);
		resetAll.setBounds(toolbarX + toolbarWidth - 58 - 70, toolbarY + 5, 66, 16);
		done.render(ui, mouseX, mouseY);
		resetAll.render(ui, mouseX, mouseY);

		float panelHeight = Math.min(ui.height() - 60, 24 + client.hud().elements().size() * 20f);
		float panelY = (ui.height() - panelHeight) / 2f;
		renderer.surface(6, panelY, PANEL_WIDTH, panelHeight, DesignTokens.RADIUS_L, ColorUtil.withAlpha(theme.panel(), 235), theme.border(), theme.shadow(), 12);
		renderer.text(ui.tr("ui.hud.elements"), 14, panelY + 7, DesignTokens.FONT_SMALL, theme.textPrimary(), FontManager.Weight.SEMIBOLD, false);
		snapping.setBounds(6 + PANEL_WIDTH - 18, panelY + 4, 14, 14);
		elementList.setBounds(8, panelY + 20, PANEL_WIDTH - 4, panelHeight - 24);
		elementList.render(ui, mouseX, mouseY);
		Icon.MOVE.draw(renderer, 6 + PANEL_WIDTH - 16, panelY + 6, 10, snapEnabled ? theme.accent() : theme.textDisabled());
		renderer.popAlpha();
	}

	private boolean overChrome(float mouseX, float mouseY) {
		float toolbarX = (context.width() - 270) / 2f;
		boolean onToolbar = mouseX >= toolbarX && mouseX <= toolbarX + 270 && mouseY >= 8 && mouseY <= 34;
		boolean onPanel = mouseX >= 6 && mouseX <= 6 + PANEL_WIDTH && elementList.contains(mouseX, mouseY - 0);
		return onToolbar || onPanel;
	}

	@Override
	protected boolean onMouseClicked(float mouseX, float mouseY, int button) {
		if (done.mouseClicked(context, mouseX, mouseY, button) || resetAll.mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		if (mouseX >= 6 + PANEL_WIDTH - 20 && mouseX <= 6 + PANEL_WIDTH && mouseY >= snapping.y() && mouseY <= snapping.y() + 14) {
			snapEnabled = !snapEnabled;
			return true;
		}
		if (elementList.mouseClicked(context, mouseX, mouseY, button) || overChrome(mouseX, mouseY)) {
			return true;
		}
		HudModule element = client.hud().elementAt(mouseX, mouseY);
		selected = element;
		if (element == null) {
			return false;
		}
		if (button == 0) {
			dragging = element;
			dragOffsetX = mouseX - element.lastX();
			dragOffsetY = mouseY - element.lastY();
			return true;
		}
		if (button == 1) {
			ContextMenu.at(mouseX, mouseY)
				.item("ui.hud.reset_position", Icon.RESET, element::resetPosition)
				.item("ui.hud.scale_reset", Icon.MINUS, () -> element.settings().find("scale").reset())
				.separator()
				.danger("ui.hud.hide", Icon.EYE_OFF, () -> element.setEnabled(false))
				.open(context);
			return true;
		}
		return true;
	}

	@Override
	protected boolean onMouseDragged(float mouseX, float mouseY, int button) {
		if (elementList.mouseDragged(context, mouseX, mouseY, button)) {
			return true;
		}
		if (dragging == null) {
			return false;
		}
		float x = mouseX - dragOffsetX;
		float y = mouseY - dragOffsetY;
		guideX = Float.NaN;
		guideY = Float.NaN;
		boolean free = (GLFW.glfwGetKey(minecraft.getWindow().handle(), GLFW.GLFW_KEY_LEFT_ALT) == GLFW.GLFW_PRESS);
		if (snapEnabled && !free) {
			float[] snappedX = snap(x, dragging.scaledWidth(), context.width(), true);
			float[] snappedY = snap(y, dragging.scaledHeight(), context.height(), false);
			x = snappedX[0];
			y = snappedY[0];
			guideX = snappedX[1];
			guideY = snappedY[1];
		}
		dragging.moveTo(x, y, context.width(), context.height());
		return true;
	}

	/** Returns {@code {position, guideLine}}; guide is NaN when nothing snapped. */
	private float[] snap(float position, float size, float screen, boolean horizontal) {
		float[] candidates = {0, screen / 2f, screen};
		float best = position;
		float guide = Float.NaN;
		float bestDistance = SNAP;
		float[] edges = {position, position + size / 2f, position + size};
		float[] offsets = {0, size / 2f, size};
		for (float line : candidates) {
			for (int i = 0; i < edges.length; i++) {
				float distance = Math.abs(edges[i] - line);
				if (distance < bestDistance) {
					bestDistance = distance;
					best = line - offsets[i];
					guide = line;
				}
			}
		}
		for (HudModule other : client.hud().elements()) {
			if (other == dragging || !other.isEnabled() || !other.isShowing()) {
				continue;
			}
			float otherStart = horizontal ? other.lastX() : other.lastY();
			float otherSize = horizontal ? other.scaledWidth() : other.scaledHeight();
			float[] lines = {otherStart, otherStart + otherSize / 2f, otherStart + otherSize};
			for (float line : lines) {
				for (int i = 0; i < edges.length; i++) {
					float distance = Math.abs(edges[i] - line);
					if (distance < bestDistance) {
						bestDistance = distance;
						best = line - offsets[i];
						guide = line;
					}
				}
			}
		}
		return new float[] {best, guide};
	}

	@Override
	protected boolean onMouseReleased(float mouseX, float mouseY, int button) {
		elementList.mouseReleased(context, mouseX, mouseY, button);
		dragging = null;
		guideX = Float.NaN;
		guideY = Float.NaN;
		return true;
	}

	@Override
	protected boolean onMouseScrolled(float mouseX, float mouseY, double amount) {
		if (elementList.contains(mouseX, mouseY)) {
			return elementList.mouseScrolled(context, mouseX, mouseY, amount);
		}
		HudModule element = client.hud().elementAt(mouseX, mouseY);
		if (element == null) {
			return false;
		}
		var scale = (dev.nyxveravisuals.setting.NumberSetting) element.settings().find("scale");
		float oldWidth = element.scaledWidth();
		float oldHeight = element.scaledHeight();
		float centerX = element.lastX() + oldWidth / 2f;
		float centerY = element.lastY() + oldHeight / 2f;
		scale.set(scale.get() + Math.signum(amount) * 0.05);
		element.moveTo(centerX - element.scaledWidth() / 2f, centerY - element.scaledHeight() / 2f, context.width(), context.height());
		return true;
	}

	@Override
	protected boolean onKeyPressed(int key, int scancode, int modifiers) {
		if (selected == null) {
			return false;
		}
		float step = (modifiers & GLFW.GLFW_MOD_SHIFT) != 0 ? 5 : 1;
		float dx = key == GLFW.GLFW_KEY_LEFT ? -step : key == GLFW.GLFW_KEY_RIGHT ? step : 0;
		float dy = key == GLFW.GLFW_KEY_UP ? -step : key == GLFW.GLFW_KEY_DOWN ? step : 0;
		if (dx != 0 || dy != 0) {
			selected.moveTo(selected.lastX() + dx, selected.lastY() + dy, context.width(), context.height());
			return true;
		}
		if (key == GLFW.GLFW_KEY_R) {
			selected.resetPosition();
			return true;
		}
		if (key == GLFW.GLFW_KEY_DELETE) {
			selected.setEnabled(false);
			selected = null;
			return true;
		}
		return false;
	}

	/** Compact toggle row in the element list. */
	private final class ElementRow extends Component {
		private final HudModule module;
		private final Toggle toggle;

		ElementRow(HudModule module) {
			this.module = module;
			this.toggle = new Toggle(module::isEnabled, module::setEnabled);
		}

		@Override
		public float preferredHeight(UiContext ui, float availableWidth) {
			return 18;
		}

		@Override
		protected void draw(UiContext ui, float mouseX, float mouseY) {
			Renderer2D renderer = ui.renderer();
			if (hover() > 0.01f) {
				renderer.rounded(x, y, width, height, DesignTokens.RADIUS_S, ColorUtil.withAlpha(ui.theme().textPrimary(), Math.round(hover() * 12)));
			}
			toggle.setBounds(x + width - DesignTokens.TOGGLE_WIDTH - 4, y + (height - DesignTokens.TOGGLE_HEIGHT) / 2f,
				DesignTokens.TOGGLE_WIDTH, DesignTokens.TOGGLE_HEIGHT);
			toggle.render(ui, mouseX, mouseY);
			String name = renderer.ellipsize(ui.tr(module.nameKey()), DesignTokens.FONT_SMALL, FontManager.Weight.MEDIUM, width - DesignTokens.TOGGLE_WIDTH - 14);
			renderer.textMiddle(name, x + 5, y + height / 2f, DesignTokens.FONT_SMALL, module.isEnabled() ? ui.theme().textPrimary() : ui.theme().textSecondary());
		}

		@Override
		public boolean mouseClicked(UiContext ui, float mouseX, float mouseY, int button) {
			if (!contains(mouseX, mouseY)) {
				return false;
			}
			module.toggle();
			return true;
		}
	}
}
