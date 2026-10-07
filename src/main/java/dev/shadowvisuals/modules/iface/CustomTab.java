package dev.shadowvisuals.modules.iface;

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

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.module.Category;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.setting.BooleanSetting;
import dev.shadowvisuals.setting.NumberSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.util.ColorUtil;

/**
 * Restyled player list. Players, names, order, header, footer, list scores and ping are exactly what the
 * server sent (same sorting as vanilla); only the presentation changes. Friends get a subtle highlight.
 */
public final class CustomTab extends Module {
	private static final Comparator<PlayerInfo> ORDER = Comparator.<PlayerInfo>comparingInt(info -> -info.getTabListOrder())
		.thenComparingInt(info -> info.getGameMode() == GameType.SPECTATOR ? 1 : 0)
		.thenComparing(info -> info.getTeam() == null ? "" : info.getTeam().getName())
		.thenComparing(info -> info.getProfile().name(), String::compareToIgnoreCase);
	private static final int MAX_ROWS = 20;

	private final ShadowClient client;
	private final NumberSetting opacity = settings().add(new NumberSetting("background_opacity", 0.85, 0.1, 1.0, 0.05));
	private final BooleanSetting showHeads = settings().add(new BooleanSetting("show_heads", true));
	private final BooleanSetting numericPing = settings().add(new BooleanSetting("numeric_ping", true));
	private final BooleanSetting highlightFriends = settings().add(new BooleanSetting("highlight_friends", true));
	private final List<PlayerInfo> players = new ArrayList<>();

	public CustomTab(ShadowClient client) {
		super("custom_tab", Category.INTERFACE);
		this.client = client;
	}

	public void render(GuiGraphics graphics, DeltaTracker deltaTracker) {
		Minecraft minecraft = Minecraft.getInstance();
		if (minecraft.player == null || minecraft.level == null) {
			return;
		}
		PlayerTabOverlay overlay = minecraft.gui.getTabList();
		Objective listObjective = minecraft.level.getScoreboard().getDisplayObjective(DisplaySlot.LIST);
		boolean show = minecraft.options.keyPlayerList.isDown()
			&& !(minecraft.isLocalServer() && minecraft.player.connection.getListedOnlinePlayers().size() <= 1 && listObjective == null);
		overlay.setVisible(show);
		if (!show) {
			return;
		}
		players.clear();
		players.addAll(minecraft.player.connection.getListedOnlinePlayers());
		players.sort(ORDER);
		if (players.size() > 80) {
			players.subList(80, players.size()).clear();
		}
		Renderer2D renderer = client.renderer().begin(graphics);
		ThemeManager theme = client.theme();
		var font = minecraft.font;
		int columns = Math.max(1, (players.size() + MAX_ROWS - 1) / MAX_ROWS);
		int rows = Math.min(MAX_ROWS, Math.max(1, (players.size() + columns - 1) / columns));
		float cellWidth = 0;
		for (PlayerInfo info : players) {
			cellWidth = Math.max(cellWidth, font.width(overlay.getNameForDisplay(info)) + scoreWidth(minecraft, listObjective, info, font));
		}
		cellWidth += (showHeads.get() ? 12 : 2) + (numericPing.get() ? 30 : 16);
		float rowHeight = 11;
		float contentWidth = columns * cellWidth + (columns - 1) * 4;
		List<Component> headerLines = lines(overlay.header);
		List<Component> footerLines = lines(overlay.footer);
		for (Component line : headerLines) {
			contentWidth = Math.max(contentWidth, font.width(line));
		}
		for (Component line : footerLines) {
			contentWidth = Math.max(contentWidth, font.width(line));
		}
		contentWidth = Math.min(contentWidth, graphics.guiWidth() - 24);
		float padding = 6;
		float headerHeight = headerLines.size() * 10 + (headerLines.isEmpty() ? 0 : 4);
		float footerHeight = footerLines.size() * 10 + (footerLines.isEmpty() ? 0 : 4);
		float width = contentWidth + padding * 2;
		float height = headerHeight + rows * rowHeight + footerHeight + padding * 2;
		float x = (graphics.guiWidth() - width) / 2f;
		float y = 10;
		renderer.shadow(x, y + 1, width, height, DesignTokens.RADIUS_L, 12, ColorUtil.withAlpha(0, Math.round(120 * opacity.getFloat())));
		renderer.rounded(x, y, width, height, DesignTokens.RADIUS_L, ColorUtil.withAlpha(theme.panel(), Math.round(255 * opacity.getFloat())));
		renderer.outline(x, y, width, height, DesignTokens.RADIUS_L, 1, ColorUtil.withAlpha(theme.border(), Math.round(255 * opacity.getFloat())));
		float cursor = y + padding;
		for (Component line : headerLines) {
			renderer.component(line, x + width / 2f - font.width(line) / 2f, cursor, 1f, 0xFFFFFFFF, false);
			cursor += 10;
		}
		if (!headerLines.isEmpty()) {
			cursor += 4;
		}
		float gridTop = cursor;
		for (int i = 0; i < players.size(); i++) {
			PlayerInfo info = players.get(i);
			int column = i / rows;
			int row = i % rows;
			float cellX = x + padding + column * (cellWidth + 4);
			float cellY = gridTop + row * rowHeight;
			boolean friend = highlightFriends.get() && client.friends().isFriend(info.getProfile().name());
			renderer.rounded(cellX, cellY, cellWidth, rowHeight - 1, DesignTokens.RADIUS_XS,
				friend ? ColorUtil.withAlpha(theme.success(), 34) : ColorUtil.withAlpha(theme.textPrimary(), 10));
			float textX = cellX + 2;
			if (showHeads.get()) {
				renderer.face(info.getSkin(), cellX + 1.5f, cellY + 1, 8);
				textX += 10;
			}
			Component name = overlay.getNameForDisplay(info);
			int nameColor = info.getGameMode() == GameType.SPECTATOR ? 0x99FFFFFF : 0xFFFFFFFF;
			renderer.component(name, textX, cellY + 1.5f, 1f, nameColor, false);
			String score = score(minecraft, listObjective, info);
			if (score != null) {
				renderer.component(Component.literal(score), textX + font.width(name) + 4, cellY + 1.5f, 1f, 0xFFF5D244, false);
			}
			drawPing(renderer, theme, info.getLatency(), cellX + cellWidth - 2, cellY + rowHeight / 2f - 0.5f);
		}
		cursor = gridTop + rows * rowHeight;
		if (!footerLines.isEmpty()) {
			cursor += 4;
		}
		for (Component line : footerLines) {
			renderer.component(line, x + width / 2f - font.width(line) / 2f, cursor, 1f, 0xFFFFFFFF, false);
			cursor += 10;
		}
	}

	private void drawPing(Renderer2D renderer, ThemeManager theme, int latency, float right, float centerY) {
		int color = latency < 0 ? theme.textDisabled() : latency < 80 ? theme.success() : latency < 160 ? theme.warning() : theme.error();
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

	private static String score(Minecraft minecraft, Objective objective, PlayerInfo info) {
		if (objective == null) {
			return null;
		}
		ReadOnlyScoreInfo score = objective.getScoreboard().getPlayerScoreInfo(ScoreHolder.fromGameProfile(info.getProfile()), objective);
		return score == null ? null : Integer.toString(score.value());
	}

	private static int scoreWidth(Minecraft minecraft, Objective objective, PlayerInfo info, net.minecraft.client.gui.Font font) {
		String score = score(minecraft, objective, info);
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
