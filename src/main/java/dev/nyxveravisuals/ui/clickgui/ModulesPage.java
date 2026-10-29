package dev.nyxveravisuals.ui.clickgui;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.Consumer;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Component;
import dev.nyxveravisuals.ui.component.ScrollPanel;

/**
 * Grid of module cards for a category, the favorites or search results. Columns adapt to the width; cards
 * are cached per module so their animations survive page switches and filtering.
 */
public final class ModulesPage extends Component {
	private final NyxveraClient client;
	private final Consumer<Module> openSettings;
	private final Map<Module, ModuleCard> cards = new HashMap<>();
	private final ScrollPanel grid = new ScrollPanel(this::layoutGrid).padding(2);
	private List<Module> modules = List.of();
	private String emptyKey = "ui.empty.category";
	private Icon emptyIcon = Icon.SEARCH;

	public ModulesPage(NyxveraClient client, Consumer<Module> openSettings) {
		this.client = client;
		this.openSettings = openSettings;
	}

	public void show(List<Module> list, String emptyMessageKey, Icon emptyStateIcon) {
		this.modules = list;
		this.emptyKey = emptyMessageKey;
		this.emptyIcon = emptyStateIcon;
		List<Component> children = new ArrayList<>(list.size());
		for (Module module : list) {
			children.add(cards.computeIfAbsent(module, key -> new ModuleCard(client, key, openSettings)));
		}
		grid.setChildren(children);
	}

	public void resetScroll() {
		grid.resetScroll();
	}

	public int count() {
		return modules.size();
	}

	private float layoutGrid(UiContext context, List<Component> children, float left, float top, float width) {
		float gap = DesignTokens.SPACE_M;
		int columns = width >= DesignTokens.CARD_MIN_WIDTH * 3 + gap * 2 ? 3 : width >= DesignTokens.CARD_MIN_WIDTH * 2 + gap ? 2 : 1;
		float cardWidth = (width - gap * (columns - 1)) / columns;
		float cardHeight = DesignTokens.CARD_HEIGHT + 2;
		for (int i = 0; i < children.size(); i++) {
			int column = i % columns;
			int row = i / columns;
			children.get(i).setBounds(left + column * (cardWidth + gap), top + row * (cardHeight + gap), cardWidth, cardHeight);
		}
		int rows = (children.size() + columns - 1) / columns;
		return rows == 0 ? 0 : rows * cardHeight + (rows - 1) * gap;
	}

	@Override
	protected void draw(UiContext context, float mouseX, float mouseY) {
		grid.setBounds(x, y, width, height);
		if (modules.isEmpty()) {
			Renderer2D renderer = context.renderer();
			float iconSize = 22;
			emptyIcon.draw(renderer, x + width / 2f - iconSize / 2f, y + height / 2f - 28, iconSize, context.theme().textDisabled());
			renderer.text(context.tr(emptyKey), x + width / 2f, y + height / 2f + 2, context.text(DesignTokens.FONT_SMALL),
				context.theme().textSecondary(), Renderer2D.Align.CENTER);
			return;
		}
		grid.render(context, mouseX, mouseY);
	}

	@Override
	public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
		return grid.mouseClicked(context, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseScrolled(UiContext context, float mouseX, float mouseY, double amount) {
		return grid.mouseScrolled(context, mouseX, mouseY, amount);
	}

	@Override
	public boolean mouseDragged(UiContext context, float mouseX, float mouseY, int button) {
		return grid.mouseDragged(context, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseReleased(UiContext context, float mouseX, float mouseY, int button) {
		return grid.mouseReleased(context, mouseX, mouseY, button);
	}
}
