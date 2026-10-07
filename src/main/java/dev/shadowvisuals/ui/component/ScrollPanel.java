package dev.shadowvisuals.ui.component;

import java.util.ArrayList;
import java.util.List;

import dev.shadowvisuals.animation.SmoothValue;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.util.ColorUtil;
import dev.shadowvisuals.util.MathUtil;

/**
 * Clipped, smoothly scrolling container. A {@link Layout} positions children in content space each frame;
 * children fully outside the viewport are neither drawn nor hit-tested.
 */
public final class ScrollPanel extends Component {
	@FunctionalInterface
	public interface Layout {
		/** Positions {@code children} starting at {@code (left, top)} and returns the total content height. */
		float apply(UiContext context, List<Component> children, float left, float top, float width);
	}

	/** Vertical stack using each child's preferred height. */
	public static Layout stack(float gap) {
		return (context, children, left, top, width) -> {
			float cursor = top;
			for (Component child : children) {
				if (!child.isVisible()) {
					continue;
				}
				float childHeight = child.preferredHeight(context, width);
				child.setBounds(left, cursor, width, childHeight);
				cursor += childHeight + gap;
			}
			return Math.max(0, cursor - top - (children.isEmpty() ? 0 : gap));
		};
	}

	private final List<Component> children = new ArrayList<>();
	private final SmoothValue scroll = new SmoothValue(0f, DesignTokens.SCROLL_SMOOTHING);
	private final Layout layout;
	private float padding;
	private float target;
	private float contentHeight;
	private boolean draggingBar;
	private float dragOffset;

	public ScrollPanel(Layout layout) {
		this.layout = layout;
	}

	public ScrollPanel padding(float value) {
		this.padding = value;
		return this;
	}

	public void setChildren(List<? extends Component> list) {
		children.clear();
		children.addAll(list);
	}

	public List<Component> children() {
		return children;
	}

	public void resetScroll() {
		target = 0;
		scroll.snap(0);
	}

	private float maxScroll() {
		return Math.max(0, contentHeight + padding * 2 - height);
	}

	private boolean inViewport(Component child) {
		return child.isVisible() && child.y() + child.height() > y && child.y() < y + height;
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		Renderer2D renderer = context.renderer();
		target = MathUtil.clamp(target, 0, maxScroll());
		scroll.setTarget(target);
		float offset = MathUtil.clamp(scroll.get(), 0, maxScroll());
		contentHeight = layout.apply(context, children, x + padding, y + padding - offset, width - padding * 2 - (maxScroll() > 0 ? 4 : 0));
		boolean inside = contains(mouseX, mouseY);
		float childMouseX = inside ? mouseX : -1e6f;
		float childMouseY = inside ? mouseY : -1e6f;
		renderer.pushClip(x, y, width, height);
		for (Component child : children) {
			if (inViewport(child)) {
				child.render(context, childMouseX, childMouseY);
			}
		}
		renderer.popClip();
		drawScrollbar(context, offset);
	}

	private void drawScrollbar(UiContext context, float offset) {
		float max = maxScroll();
		if (max <= 0) {
			return;
		}
		ThemeManager theme = context.theme();
		Renderer2D renderer = context.renderer();
		float total = contentHeight + padding * 2;
		float barHeight = Math.max(18, height * height / total);
		float barY = y + (height - barHeight) * (offset / max);
		float barX = x + width - DesignTokens.SCROLLBAR_WIDTH - 1;
		int color = ColorUtil.withAlpha(theme.textSecondary(), draggingBar ? 150 : 70 + Math.round(hover() * 40));
		renderer.rounded(barX, barY + 2, DesignTokens.SCROLLBAR_WIDTH, barHeight - 4, DesignTokens.SCROLLBAR_WIDTH / 2f, color);
		if (offset > 1) {
			renderer.gradientVertical(x, y, width - 6, 8, 0, ColorUtil.withAlpha(0, 60), 0);
		}
		if (offset < max - 1) {
			renderer.gradientVertical(x, y + height - 8, width - 6, 8, 0, 0, ColorUtil.withAlpha(0, 60));
		}
	}

	private boolean onScrollbar(float mouseX) {
		return maxScroll() > 0 && mouseX >= x + width - DesignTokens.SCROLLBAR_WIDTH - 4;
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		if (!contains(mouseX, mouseY)) {
			return false;
		}
		if (button == 0 && onScrollbar(mouseX)) {
			float total = contentHeight + padding * 2;
			float barHeight = Math.max(18, height * height / total);
			float barY = y + (height - barHeight) * (scroll.get() / Math.max(1, maxScroll()));
			draggingBar = true;
			dragOffset = mouseY >= barY && mouseY <= barY + barHeight ? mouseY - barY : barHeight / 2f;
			mouseDragged(context, mouseX, mouseY, button);
			return true;
		}
		for (int i = children.size() - 1; i >= 0; i--) {
			Component child = children.get(i);
			if (inViewport(child) && child.mouseClicked(context, mouseX, mouseY, button)) {
				return true;
			}
		}
		return false;
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		if (draggingBar) {
			float total = contentHeight + padding * 2;
			float barHeight = Math.max(18, height * height / total);
			float progress = MathUtil.clamp((mouseY - dragOffset - y) / Math.max(1, height - barHeight), 0, 1);
			target = progress * maxScroll();
			scroll.snap(target);
			return true;
		}
		for (Component child : children) {
			if (child.mouseDragged(context, mouseX, mouseY, button)) {
				return true;
			}
		}
		return false;
	}

	@Override
	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		draggingBar = false;
		boolean consumed = false;
		for (Component child : children) {
			consumed |= child.mouseReleased(context, mouseX, mouseY, button);
		}
		return consumed;
	}

	@Override
	public boolean mouseScrolled(UiContext context, float mouseX, float mouseY, double amount) {
		if (!contains(mouseX, mouseY)) {
			return false;
		}
		for (Component child : children) {
			if (inViewport(child) && child.contains(mouseX, mouseY) && child.mouseScrolled(context, mouseX, mouseY, amount)) {
				return true;
			}
		}
		if (maxScroll() <= 0) {
			return false;
		}
		target = MathUtil.clamp(target - (float) amount * 28f, 0, maxScroll());
		return true;
	}

	@Override
	public boolean keyPressed(UiContext context, int key, int scancode, int modifiers) {
		for (Component child : children) {
			if (inViewport(child) && child.keyPressed(context, key, scancode, modifiers)) {
				return true;
			}
		}
		return false;
	}
}
