package dev.nyxveravisuals.ui.settings;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.function.BooleanSupplier;
import java.util.function.Predicate;

import dev.nyxveravisuals.animation.Animation;
import dev.nyxveravisuals.animation.Easing;
import dev.nyxveravisuals.core.UiSounds;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.render.font.FontManager;
import dev.nyxveravisuals.setting.SettingGroup;
import dev.nyxveravisuals.setting.SettingNode;
import dev.nyxveravisuals.setting.SettingRegistry;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.ui.Icon;
import dev.nyxveravisuals.ui.UiContext;
import dev.nyxveravisuals.ui.component.Component;

/** Builds the row components for a setting tree; groups become collapsible headers. */
public final class SettingsList {
	private SettingsList() {
	}

	/** Collapsed state survives rebuilding the list while the screen is open. */
	private static final Map<SettingGroup, Boolean> EXPANDED = new HashMap<>();

	public static List<Component> build(UiContext context, SettingRegistry registry, Predicate<SettingNode> include) {
		List<Component> rows = new ArrayList<>();
		for (SettingNode node : registry.roots()) {
			add(context, node, include, () -> true, 0, rows);
		}
		return rows;
	}

	private static void add(UiContext context, SettingNode node, Predicate<SettingNode> include, BooleanSupplier parentOpen, float indent, List<Component> rows) {
		if (node.isInternal() || !include.test(node)) {
			return;
		}
		if (node instanceof SettingGroup group) {
			GroupHeader header = new GroupHeader(group, parentOpen, indent);
			rows.add(header);
			BooleanSupplier open = () -> parentOpen.getAsBoolean() && header.expanded();
			for (SettingNode child : group.children()) {
				add(context, child, include, open, indent + 6, rows);
			}
			return;
		}
		rows.add(new SettingRow(context, node, parentOpen, indent));
	}

	/** Collapsible group title. */
	static final class GroupHeader extends Component {
		private final SettingGroup group;
		private final BooleanSupplier parentOpen;
		private final float indent;
		private final Animation chevron;

		GroupHeader(SettingGroup group, BooleanSupplier parentOpen, float indent) {
			this.group = group;
			this.parentOpen = parentOpen;
			this.indent = indent;
			this.chevron = new Animation(expanded() ? 1f : 0f, DesignTokens.DURATION_HOVER, Easing.EASE_OUT_QUAD);
		}

		boolean expanded() {
			return EXPANDED.getOrDefault(group, group.expandedByDefault());
		}

		@Override
		public boolean isVisible() {
			return group.isVisible() && parentOpen.getAsBoolean();
		}

		@Override
		public float preferredHeight(UiContext context, float availableWidth) {
			return 18;
		}

		@Override
		protected void draw(UiContext context, float mouseX, float mouseY) {
			Renderer2D renderer = context.renderer();
			ThemeManager theme = context.theme();
			chevron.animateTo(expanded() ? 1f : 0f);
			float left = x + indent;
			float iconSize = 7;
			renderer.push();
			float cx = left + iconSize / 2f;
			float cy = y + height / 2f;
			renderer.translate(cx, cy);
			renderer.pose().rotate((float) (Math.PI / 2 * chevron.value()));
			renderer.translate(-cx, -cy);
			Icon.CHEVRON_RIGHT.draw(renderer, left, cy - iconSize / 2f, iconSize, theme.textSecondary());
			renderer.pop();
			float size = context.text(DesignTokens.FONT_CAPTION);
			String title = context.i18n().settingName(group).toUpperCase(java.util.Locale.ROOT);
			renderer.textMiddle(title, left + iconSize + 5, cy, size, isHovered() ? theme.textPrimary() : theme.textSecondary(),
				FontManager.Weight.SEMIBOLD, Renderer2D.Align.LEFT);
			float titleEnd = left + iconSize + 5 + renderer.textWidth(title, size, FontManager.Weight.SEMIBOLD) + 6;
			renderer.rect(titleEnd, cy, Math.max(0, x + width - titleEnd), 1, theme.border());
		}

		@Override
		public boolean mouseClicked(UiContext context, float mouseX, float mouseY, int button) {
			if (button != 0 || !contains(mouseX, mouseY)) {
				return false;
			}
			EXPANDED.put(group, !expanded());
			context.sounds().play(UiSounds.Kind.CLICK);
			return true;
		}
	}
}
