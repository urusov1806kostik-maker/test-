package dev.nyxveravisuals.modules.iface;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.components.PlayerTabOverlay;
import net.minecraft.client.multiplayer.PlayerInfo;
import net.minecraft.network.chat.Component;
import net.minecraft.world.level.GameType;
import net.minecraft.world.scores.DisplaySlot;
import net.minecraft.world.scores.Objective;
import net.minecraft.world.scores.ReadOnlyScoreInfo;
import net.minecraft.world.scores.ScoreHolder;

import dev.nyxveravisuals.NyxveraClient;
import dev.nyxveravisuals.animation.Animation;
import dev.nyxveravisuals.animation.Easing;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.module.Module;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.NumberSetting;
import dev.nyxveravisuals.theme.DesignTokens;
import dev.nyxveravisuals.theme.ThemeManager;
import dev.nyxveravisuals.util.ColorUtil;

/**
 * Restyled player list. Players, names, order, header, footer, list scores and ping are exactly what the
 * server sent (same sorting as vanilla); only the presentation changes: it slides in and out, adapts its
 * column count to the screen, shows the online count and your ping, highlights you and your friends, and
 * says how many players did not fit instead of silently cutting the list.
 */
public final class CustomTab extends Module {
	private static final Comparator<PlayerInfo> ORDER = Comparator.<PlayerInfo>comparingInt(info -> -info.getTabListOrder())
		.thenComparingInt(info -> info.getGameMode() == GameType.SPECTATOR ? 1 : 0)
		.thenComparing(info -> info.getTeam() == null ? "" : info.getTeam().getName())
		.thenComparing(info -> info.getProfile().name(), String::compareToIgnoreCase);
	private static final int MAX_ROWS = 20;
	private static final float ROW_HEIGHT = 11;
	private static final float COLUMN_GAP = 4;
	private static final float PADDING = 6;

	private final NyxveraClient client;
	private final NumberSetting opacity = settings().add(new NumberSetting("background_opacity", 0.85, 0.1, 1.0, 0.05));
	private final BooleanSetting showHeads = settings().add(new BooleanSetting("show_heads", true));
	private final BooleanSetting numericPing = settings().add(new BooleanSetting("numeric_ping", true));
	private final BooleanSetting highlightFriends = settings().add(new BooleanSetting("highlight_friends", true));
	private final BooleanSetting highlightSelf = settings().add(new BooleanSetting("highlight_self", true));
	private final BooleanSetting showCount = settings().add(new BooleanSetting("show_count", true));
	private final List<PlayerInfo> players = new ArrayList<>();
	private final Animation presence = new Animation(0f, DesignTokens.DURATION_PANEL, Easing.EASE_OUT_CUBIC);
	private Component cachedHeader;
	private Component cachedFooter;
	private List<Component> headerLines = List.of();
	private List<Component> footerLines = List.of();
	private int totalOnline;

	public CustomTab(NyxveraClient client) {
		super("custom_tab", Category.INTERFACE);
		this.client = client;
	}

	@Override
	protected void onDisable() {
		presence.snapTo(0f);
		players.clear();
		cachedHeader = null;
		cachedFooter = null;
	}

	public void render(GuiGraphics graphics, DeltaTracker deltaTracker) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.player == null || minecraft.level == null) {
			presence.snapTo(0f);
			return;
		}
		PlayerTabOverlay overlay = minecraft.gui.getTabList();
		Objective listObjective = minecraft.level.getScoreboard().getDisplayObjective(DisplaySlot.LIST);
		boolean show = minecraft.options.keyPlayerList.isDown()
			&& !(minecraft.isLocalServer() && minecraft.player.connection.getListedOnlinePlayers().size() <= 1 && listObjective == null);
		overlay.setVisible(show);
		presence.animateTo(show ? 1f : 0f);
		float amount = presence.value();
		if (amount <= 0.01f) {
			return;
		}
		if (show) {
			// While closing, the last snapshot keeps animating out instead of changing under the cursor.
			players.clear();
			players.addAll(minecraft.player.connection.getListedOnlinePlayers());
			players.sort(ORDER);
			totalOnline = players.size();
			refreshHeaderFooter(overlay);
		}
		Renderer2D renderer = client.renderer().begin(graphics);
		ThemeManager theme = client.theme();
		var font = minecraft.font;
		float cellWidth = 0;
		for (PlayerInfo info : players) {
			cellWidth = Math.max(cellWidth, font.width(overlay.getNameForDisplay(info)) + scoreWidth(listObjective, info, font));
		}
		cellWidth += (showHeads.get() ? 12 : 2) + (numericPing.get() ? 30 : 16);
		float maxContent = graphics.guiWidth() - 24 - PADDING * 2;
		int maxColumns = Math.max(1, (int) ((maxContent + COLUMN_GAP) / (cellWidth + COLUMN_GAP)));
		int capacity = maxColumns * MAX_ROWS;
		boolean truncated = players.size() > capacity;
		int shown = truncated ? capacity - 1 : players.size();
		int cells = truncated ? capacity : shown;
		int columns = Math.max(1, (cells + MAX_ROWS - 1) / MAX_ROWS);
		int rows = Math.min(MAX_ROWS, Math.max(1, (cells + columns - 1) / columns));
		float contentWidth = columns * cellWidth + (columns - 1) * COLUMN_GAP;
		for (Component line : headerLines) {
			contentWidth = Math.max(contentWidth, font.width(line));
		}
		for (Component line : footerLines) {
			contentWidth = Math.max(contentWidth, font.width(line));
		}
		contentWidth = Math.min(contentWidth, maxContent);
		float headerHeight = headerLines.size() * 10 + (headerLines.isEmpty() ? 0 : 4);
		float infoHeight = showCount.get() ? 12 : 0;
		float footerHeight = footerLines.size() * 10 + (footerLines.isEmpty() ? 0 : 4);
		float width = contentWidth + PADDING * 2;
		float height = headerHeight + infoHeight + rows * ROW_HEIGHT + footerHeight + PADDING * 2;
		float x = (graphics.guiWidth() - width) / 2f;
		float y = 10;
		renderer.push();
		renderer.translate(0, -8 * (1f - amount));
		renderer.scaleAround(0.96f + 0.04f * amount, graphics.guiWidth() / 2f, y);
		renderer.pushAlpha(amount);
		try {
			float alpha = opacity.getFloat();
			renderer.shadow(x, y + 1, width, height, DesignTokens.RADIUS_L, 12, ColorUtil.withAlpha(0, Math.round(120 * alpha)));
			renderer.rounded(x, y, width, height, DesignTokens.RADIUS_L, ColorUtil.withAlpha(theme.panel(), Math.round(255 * alpha)));
			renderer.outline(x, y, width, height, DesignTokens.RADIUS_L, 1, ColorUtil.withAlpha(theme.border(), Math.round(255 * alpha)));
			float cursor = y + PADDING;
			for (Component line : headerLines) {
				renderer.component(line, x + width / 2f - font.width(line) / 2f, cursor, 1f, 0xFFFFFFFF, false);
				cursor += 10;
			}
			if (!headerLines.isEmpty()) {
				cursor += 4;
			}
			if (showCount.get()) {
				drawInfo(renderer, theme, minecraft, x + PADDING, cursor, contentWidth);
				cursor += infoHeight;
			}
			float gridTop = cursor;
			String self = minecraft.player.getGameProfile().name();
			for (int i = 0; i < shown; i++) {
				PlayerInfo info = players.get(i);
				float cellX = x + PADDING + (i / rows) * (cellWidth + COLUMN_GAP);
				float cellY = gridTop + (i % rows) * ROW_HEIGHT;
				drawCell(renderer, theme, overlay, listObjective, info, self, cellX, cellY, cellWidth);
			}
			if (truncated) {
				float cellX = x + PADDING + (shown / rows) * (cellWidth + COLUMN_GAP);
				float cellY = gridTop + (shown % rows) * ROW_HEIGHT;
				String more = client.i18n().tr("ui.tab.more", totalOnline - shown);
				renderer.text(more, cellX + 3, cellY + ROW_HEIGHT / 2f - 0.5f - renderer.fonts().visualCenter(7f), 7f, theme.textSecondary());
			}
			cursor = gridTop + rows * ROW_HEIGHT;
			if (!footerLines.isEmpty()) {
				cursor += 4;
			}
			for (Component line : footerLines) {
				renderer.component(line, x + width / 2f - font.width(line) / 2f, cursor, 1f, 0xFFFFFFFF, false);
				cursor += 10;
			}
		} finally {
			renderer.popAlpha();
			renderer.pop();
		}
	}

	private void drawInfo(Renderer2D renderer, ThemeManager theme, Minecraft minecraft, float x, float y, float width) {
		float size = 7f;
		float centerY = y + 4.5f;
		String online = client.i18n().tr("ui.tab.online", totalOnline);
		renderer.circle(x + 2.5f, centerY, 2f, theme.success());
		renderer.text(online, x + 7, centerY - renderer.fonts().visualCenter(size), size, theme.textSecondary());
		PlayerInfo own = minecraft.getConnection() == null ? null : minecraft.getConnection().getPlayerInfo(minecraft.player.getUUID());
		if (own != null) {
			String ping = client.i18n().tr("ui.tab.your_ping", own.getLatency());
			renderer.text(ping, x + width, centerY - renderer.fonts().visualCenter(size), size, pingColor(theme, own.getLatency()),
				Renderer2D.Align.RIGHT);
		}
		renderer.rect(x, y + 10, width, 1, ColorUtil.withAlpha(theme.textPrimary(), 14));
	}

	private void drawCell(Renderer2D renderer, ThemeManager theme, PlayerTabOverlay overlay, Objective listObjective, PlayerInfo info,
		String self, float cellX, float cellY, float cellWidth) {
		var font = Minecraft.getInstance().font;
		String profileName = info.getProfile().name();
		boolean you = highlightSelf.get() && profileName.equals(self);
		boolean friend = highlightFriends.get() && client.friends().isFriend(profileName);
		int background = you ? theme.accentMuted(46) : friend ? ColorUtil.withAlpha(theme.success(), 34) : ColorUtil.withAlpha(theme.textPrimary(), 10);
		renderer.rounded(cellX, cellY, cellWidth, ROW_HEIGHT - 1, DesignTokens.RADIUS_XS, background);
		if (you || friend) {
			renderer.rounded(cellX, cellY + 1.5f, 1.5f, ROW_HEIGHT - 4, 0.75f, you ? theme.accent() : theme.success());
		}
		float textX = cellX + 3;
		if (showHeads.get()) {
			renderer.face(info.getSkin(), cellX + 2.5f, cellY + 1, 8);
			textX += 10;
		}
		Component name = overlay.getNameForDisplay(info);
		int nameColor = info.getGameMode() == GameType.SPECTATOR ? 0x99FFFFFF : 0xFFFFFFFF;
		renderer.component(name, textX, cellY + 1.5f, 1f, nameColor, false);
		String score = score(listObjective, info);
		if (score != null) {
			renderer.component(Component.literal(score), textX + font.width(name) + 4, cellY + 1.5f, 1f, 0xFFF5D244, false);
		}
		drawPing(renderer, theme, info.getLatency(), cellX + cellWidth - 2, cellY + ROW_HEIGHT / 2f - 0.5f);
	}

	/** Re-splits the server header and footer only when the server changes them. */
	private void refreshHeaderFooter(PlayerTabOverlay overlay) {
		if (overlay.header != cachedHeader) {
			cachedHeader = overlay.header;
			headerLines = lines(cachedHeader);
		}
		if (overlay.footer != cachedFooter) {
			cachedFooter = overlay.footer;
			footerLines = lines(cachedFooter);
		}
	}

	private static int pingColor(ThemeManager theme, int latency) {
		return latency < 0 ? theme.textDisabled() : latency < 80 ? theme.success() : latency < 160 ? theme.warning() : theme.error();
	}

	private void drawPing(Renderer2D renderer, ThemeManager theme, int latency, float right, float centerY) {
		int color = pingColor(theme, latency);
		if (numericPing.get()) {
			String text = latency < 0 ? "?" : latency + "ms";
			renderer.text(text, right, centerY - renderer.fonts().visualCenter(6.5f), 6.5f, color, Renderer2D.Align.RIGHT);
			return;
		}
		int bars = latency < 0 ? 0 : latency < 150 ? 5 : latency < 300 ? 4 : latency < 600 ? 3 : latency < 1000 ? 2 : 1;
		for (int i = 0; i < 5; i++) {
			float barHeight = 2 + i * 1.2f;
			renderer.rect(right - 12 + i * 2.5f, centerY + 4 - barHeight, 1.6f, barHeight, i < bars ? color : ColorUtil.withAlpha(theme.textSecondary(), 70));
		}
	}

	private static String score(Objective objective, PlayerInfo info) {
		if (objective == null) {
			return null;
		}
		ReadOnlyScoreInfo score = objective.getScoreboard().getPlayerScoreInfo(ScoreHolder.fromGameProfile(info.getProfile()), objective);
		return score == null ? null : Integer.toString(score.value());
	}

	private static int scoreWidth(Objective objective, PlayerInfo info, net.minecraft.client.gui.Font font) {
		String score = score(objective, info);
		return score == null ? 0 : font.width(score) + 4;
	}

	/** Splits server header/footer text at line breaks, keeping all styling. */
	private static List<Component> lines(Component text) {
		if (text == null || text.getString().isEmpty()) {
			return List.of();
		}
		List<Component> result = new ArrayList<>();
		var splitter = Minecraft.getInstance().font.getSplitter();
		for (net.minecraft.network.chat.FormattedText line : splitter.splitLines(text, Integer.MAX_VALUE, net.minecraft.network.chat.Style.EMPTY)) {
			net.minecraft.network.chat.MutableComponent component = Component.empty();
			line.visit((style, value) -> {
				component.append(Component.literal(value).withStyle(style));
				return java.util.Optional.empty();
			}, net.minecraft.network.chat.Style.EMPTY);
			result.add(component);
		}
		return result;
	}
}
