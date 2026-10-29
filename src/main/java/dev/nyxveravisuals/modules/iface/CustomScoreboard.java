package dev.nyxveravisuals.modules.iface;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

import net.minecraft.client.Minecraft;
import net.minecraft.network.chat.Component;
import net.minecraft.network.chat.numbers.NumberFormat;
import net.minecraft.network.chat.numbers.StyledFormat;
import net.minecraft.world.scores.DisplaySlot;
import net.minecraft.world.scores.Objective;
import net.minecraft.world.scores.PlayerScoreEntry;
import net.minecraft.world.scores.PlayerTeam;
import net.minecraft.world.scores.Scoreboard;

import dev.nyxveravisuals.hud.HudAnchor;
import dev.nyxveravisuals.hud.HudContext;
import dev.nyxveravisuals.hud.PanelHudModule;
import dev.nyxveravisuals.module.Category;
import dev.nyxveravisuals.render.Renderer2D;
import dev.nyxveravisuals.setting.BooleanSetting;

/**
 * Restyled sidebar scoreboard. The server's text, formatting and order are kept exactly (same selection and
 * sorting as vanilla); only the background, spacing and position change. Movable in the HUD editor.
 */
public final class CustomScoreboard extends PanelHudModule {
	private static final Comparator<PlayerScoreEntry> ORDER = Comparator.comparing(PlayerScoreEntry::value).reversed()
		.thenComparing(PlayerScoreEntry::owner, String.CASE_INSENSITIVE_ORDER);

	private record Line(Component name, Component score) {
	}

	private final BooleanSetting showNumbers = settings().add(new BooleanSetting("show_numbers", true));
	private final List<Line> lines = new ArrayList<>(16);

	public CustomScoreboard() {
		super("custom_scoreboard", Category.INTERFACE, false, HudAnchor.MIDDLE_RIGHT, -4, 0);
	}

	public boolean hidesVanilla() {
		return isEnabled();
	}

	private static Objective objective(Minecraft minecraft) {
		if (minecraft.level == null || minecraft.player == null) {
			return null;
		}
		Scoreboard scoreboard = minecraft.level.getScoreboard();
		PlayerTeam team = scoreboard.getPlayersTeam(minecraft.player.getScoreboardName());
		if (team != null) {
			DisplaySlot slot = DisplaySlot.teamColorToSlot(team.getColor());
			if (slot != null && scoreboard.getDisplayObjective(slot) != null) {
				return scoreboard.getDisplayObjective(slot);
			}
		}
		return scoreboard.getDisplayObjective(DisplaySlot.SIDEBAR);
	}

	@Override
	protected boolean hasContent(HudContext context) {
		return objective(Minecraft.getInstance()) != null;
	}

	@Override
	protected void renderContent(HudContext context) {
		Minecraft minecraft = Minecraft.getInstance();
		Objective objective = objective(minecraft);
		Renderer2D renderer = context.renderer();
		var font = minecraft.font;
		lines.clear();
		Component title = Component.literal("Scoreboard");
		if (objective != null) {
			Scoreboard scoreboard = objective.getScoreboard();
			NumberFormat format = objective.numberFormatOrDefault(StyledFormat.SIDEBAR_DEFAULT);
			scoreboard.listPlayerScores(objective).stream()
				.filter(entry -> !entry.isHidden())
				.sorted(ORDER)
				.limit(15)
				.forEach(entry -> lines.add(new Line(PlayerTeam.formatNameForTeam(scoreboard.getPlayersTeam(entry.owner()), entry.ownerName()),
					entry.formatValue(format))));
			title = objective.getDisplayName();
		}
		int titleWidth = font.width(title);
		int width = titleWidth;
		for (Line line : lines) {
			int scoreWidth = showNumbers.get() ? font.width(line.score()) : 0;
			width = Math.max(width, font.width(line.name()) + (scoreWidth > 0 ? font.width(": ") + scoreWidth : 0));
		}
		float rowHeight = 9;
		float panelWidth = width + PADDING * 2 + 2;
		float panelHeight = 12 + lines.size() * rowHeight + PADDING * 2 - 2;
		panel(context, panelWidth, panelHeight);
		renderer.component(title, PADDING + 1 + (width - titleWidth) / 2f, PADDING, 1f, 0xFFFFFFFF, false);
		renderer.rect(PADDING, PADDING + 10.5f, width + 2, 1, context.theme().border());
		float y = PADDING + 13;
		for (Line line : lines) {
			renderer.component(line.name(), PADDING + 1, y, 1f, 0xFFFFFFFF, false);
			if (showNumbers.get()) {
				renderer.component(line.score(), PADDING + 1 + width - font.width(line.score()), y, 1f, 0xFFFFFFFF, false);
			}
			y += rowHeight;
		}
		setSize(panelWidth, panelHeight);
	}
}
