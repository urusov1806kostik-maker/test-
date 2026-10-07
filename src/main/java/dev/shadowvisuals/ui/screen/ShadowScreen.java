package dev.shadowvisuals.ui.screen;

import org.lwjgl.glfw.GLFW;

import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.input.CharacterEvent;
import net.minecraft.client.input.KeyEvent;
import net.minecraft.client.input.MouseButtonEvent;
import net.minecraft.network.chat.Component;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.animation.Animation;
import dev.shadowvisuals.animation.Easing;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Bridge between a vanilla {@link Screen} and the Shadow Visuals component system: logical scaling,
 * open/close transitions, blur/dim background and input routing (overlays first, then focus, then the
 * content). Subclasses implement the {@code on*} hooks in logical coordinates.
 */
public abstract class ShadowScreen extends Screen {
	protected final ShadowClient client;
	protected final UiContext context;
	private final Animation openAnimation = new Animation(0f, DesignTokens.DURATION_SCREEN, Easing.EASE_OUT_CUBIC);
	private boolean closing;
	private Screen parent;
	private float lastMouseX;
	private float lastMouseY;

	protected ShadowScreen(ShadowClient client, String titleKey) {
		super(Component.literal(client.i18n().tr(titleKey)));
		this.client = client;
		this.context = new UiContext(client);
		openAnimation.animateTo(1f);
	}

	/** Logical size of the main panel; the screen scales down to keep it fully visible. */
	protected abstract float designWidth();

	protected abstract float designHeight();

	protected abstract void renderContent(UiContext context, float mouseX, float mouseY, float openProgress);

	protected boolean onMouseClicked(float mouseX, float mouseY, int button) {
		return false;
	}

	protected boolean onMouseReleased(float mouseX, float mouseY, int button) {
		return false;
	}

	protected boolean onMouseDragged(float mouseX, float mouseY, int button) {
		return false;
	}

	protected boolean onMouseScrolled(float mouseX, float mouseY, double amount) {
		return false;
	}

	protected boolean onKeyPressed(int key, int scancode, int modifiers) {
		return false;
	}

	protected boolean onCharTyped(int codePoint) {
		return false;
	}

	/** Escape pressed with no focused widget or overlay: return true if handled (e.g. closing a sub-panel). */
	protected boolean onEscape() {
		return false;
	}

	protected boolean dimsBackground() {
		return true;
	}

	protected float uiScale() {
		float user = client.settings().uiScale.getFloat();
		float fitWidth = width * 0.96f / designWidth();
		float fitHeight = height * 0.94f / designHeight();
		return Math.max(0.35f, Math.min(user, Math.min(fitWidth, fitHeight)));
	}

	/** Screen to return to on close (e.g. the title screen or the ClickGUI for the HUD editor). */
	public void setParent(Screen screen) {
		this.parent = screen;
	}

	public boolean isClosing() {
		return closing;
	}

	private void reopenAfterChild() {
		closing = false;
		openAnimation.snapTo(1f);
	}

	/** Re-opening while the close animation runs simply reverses it. */
	public void reopen() {
		if (closing) {
			closing = false;
			openAnimation.animateTo(1f);
		}
	}

	@Override
	public void onClose() {
		if (closing) {
			finishClose();
			return;
		}
		closing = true;
		context.clearFocus();
		context.overlays().closeAll();
		openAnimation.animateTo(0f);
		if (openAnimation.isFinishedAtZero()) {
			finishClose();
		}
	}

	private void finishClose() {
		if (minecraft != null && minecraft.screen == this) {
			Screen target = parent;
			if (target instanceof ShadowScreen shadow) {
				shadow.reopenAfterChild();
			}
			minecraft.setScreen(target);
		}
	}

	@Override
	public void removed() {
		context.clearFocus();
		context.tooltips().reset();
		client.config().flush();
	}

	@Override
	public boolean isPauseScreen() {
		return false;
	}

	@Override
	public void renderBackground(GuiGraphics graphics, int mouseX, int mouseY, float partialTick) {
		if (!dimsBackground()) {
			return;
		}
		float open = openAnimation.value();
		if (minecraft != null && minecraft.level != null && client.settings().backgroundBlur.get() && open > 0.35f) {
			graphics.blurBeforeThisStratum();
		}
		Renderer2D renderer = client.renderer().begin(graphics);
		int top = ColorUtil.withAlpha(client.theme().background(), Math.round(120 * open));
		int bottom = ColorUtil.withAlpha(client.theme().background(), Math.round(170 * open));
		renderer.gradientVertical(0, 0, width, height, 0, top, bottom);
	}

	@Override
	public void render(GuiGraphics graphics, int mouseX, int mouseY, float partialTick) {
		if (closing && openAnimation.isFinishedAtZero()) {
			finishClose();
			return;
		}
		Renderer2D renderer = client.renderer().begin(graphics);
		float scale = uiScale();
		context.setViewport(scale, width / scale, height / scale);
		float logicalX = mouseX / scale;
		float logicalY = mouseY / scale;
		lastMouseX = logicalX;
		lastMouseY = logicalY;
		boolean blocked = context.overlays().captures(logicalX, logicalY) || closing;
		float contentMouseX = blocked ? -1e6f : logicalX;
		float contentMouseY = blocked ? -1e6f : logicalY;

		renderer.push();
		renderer.scale(scale);
		context.tooltips().beginFrame();
		float open = openAnimation.value();
		renderContent(context, contentMouseX, contentMouseY, open);
		context.overlays().render(context, closing ? -1e6f : logicalX, closing ? -1e6f : logicalY);
		if (!closing) {
			context.tooltips().render(context);
		}
		renderer.pop();
	}

	protected float lastMouseX() {
		return lastMouseX;
	}

	protected float lastMouseY() {
		return lastMouseY;
	}

	// ------------------------------------------------------------------ input routing

	@Override
	public boolean mouseClicked(MouseButtonEvent event, boolean doubleClick) {
		if (closing) {
			return true;
		}
		float scale = uiScale();
		float mouseX = (float) event.x() / scale;
		float mouseY = (float) event.y() / scale;
		int button = event.button();
		if (context.overlays().mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		dev.shadowvisuals.ui.component.Component focused = context.focused();
		if (focused != null && focused.mouseClicked(context, mouseX, mouseY, button)) {
			return true;
		}
		return onMouseClicked(mouseX, mouseY, button);
	}

	@Override
	public boolean mouseReleased(MouseButtonEvent event) {
		float scale = uiScale();
		float mouseX = (float) event.x() / scale;
		float mouseY = (float) event.y() / scale;
		context.overlays().mouseReleased(context, mouseX, mouseY, event.button());
		onMouseReleased(mouseX, mouseY, event.button());
		return true;
	}

	@Override
	public boolean mouseDragged(MouseButtonEvent event, double deltaX, double deltaY) {
		if (closing) {
			return true;
		}
		float scale = uiScale();
		float mouseX = (float) event.x() / scale;
		float mouseY = (float) event.y() / scale;
		if (context.overlays().mouseDragged(context, mouseX, mouseY, event.button())) {
			return true;
		}
		dev.shadowvisuals.ui.component.Component focused = context.focused();
		if (focused != null && focused.mouseDragged(context, mouseX, mouseY, event.button())) {
			return true;
		}
		return onMouseDragged(mouseX, mouseY, event.button());
	}

	@Override
	public boolean mouseScrolled(double mouseX, double mouseY, double horizontal, double vertical) {
		if (closing) {
			return true;
		}
		float scale = uiScale();
		float x = (float) mouseX / scale;
		float y = (float) mouseY / scale;
		if (context.overlays().mouseScrolled(context, x, y, vertical)) {
			return true;
		}
		return onMouseScrolled(x, y, vertical);
	}

	@Override
	public boolean keyPressed(KeyEvent event) {
		int key = event.key();
		if (closing) {
			if (key == GLFW.GLFW_KEY_ESCAPE) {
				finishClose();
			}
			return true;
		}
		if (context.overlays().keyPressed(context, key, event.scancode(), event.modifiers())) {
			return true;
		}
		dev.shadowvisuals.ui.component.Component focused = context.focused();
		if (focused != null) {
			if (focused.keyPressed(context, key, event.scancode(), event.modifiers())) {
				return true;
			}
			if (key == GLFW.GLFW_KEY_ESCAPE) {
				context.clearFocus();
				return true;
			}
		}
		if (onKeyPressed(key, event.scancode(), event.modifiers())) {
			return true;
		}
		if (key == GLFW.GLFW_KEY_ESCAPE) {
			if (!onEscape()) {
				onClose();
			}
			return true;
		}
		return false;
	}

	@Override
	public boolean charTyped(CharacterEvent event) {
		if (closing) {
			return true;
		}
		if (context.overlays().charTyped(context, event.codepoint())) {
			return true;
		}
		dev.shadowvisuals.ui.component.Component focused = context.focused();
		if (focused != null && focused.charTyped(context, event.codepoint())) {
			return true;
		}
		return onCharTyped(event.codepoint());
	}
}
