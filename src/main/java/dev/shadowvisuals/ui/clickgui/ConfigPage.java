package dev.shadowvisuals.ui.clickgui;

import java.util.ArrayList;
import java.util.List;

import net.minecraft.client.Minecraft;
import net.minecraft.client.player.LocalPlayer;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.config.ProfileManager;
import dev.shadowvisuals.notification.NotificationManager;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.ColorSetting;
import dev.shadowvisuals.theme.DesignTokens;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.Icon;
import dev.shadowvisuals.ui.UiContext;
import dev.shadowvisuals.ui.component.Button;
import dev.shadowvisuals.ui.component.ColorSwatch;
import dev.shadowvisuals.ui.component.Component;
import dev.shadowvisuals.ui.component.ScrollPanel;
import dev.shadowvisuals.ui.component.Tabs;
import dev.shadowvisuals.ui.component.TextField;
import dev.shadowvisuals.ui.component.Toggle;
import dev.shadowvisuals.ui.overlay.Dialog;
import dev.shadowvisuals.util.ColorUtil;
import dev.shadowvisuals.waypoint.Waypoint;

/** Config page: profile management, friend list and waypoints of the current world. */
public final class ConfigPage extends Component {
	private static final int PROFILES = 0;
	private static final int FRIENDS = 1;
	private static final int WAYPOINTS = 2;
	private static final int[] WAYPOINT_COLORS = {0xFF8B7CF6, 0xFF5B8CFF, 0xFF3DD68C, 0xFFF5B544, 0xFFF2555A, 0xFFE9EAF0};

	private final ShadowClient client;
	private final Tabs tabs;
	private final ScrollPanel list = new ScrollPanel(ScrollPanel.stack(4)).padding(2);
	private final TextField input = new TextField(32);
	private final Button primary;
	private final Button saveProfile;
	private final Button clearDeaths;
	private UiContext context;
	private int tab = PROFILES;
	private Object listSource;
	private int listRevision = -1;

	public ConfigPage(ShadowClient client) {
		this.client = client;
		this.tabs = new Tabs(List.of("ui.config.profiles", "ui.config.friends", "ui.config.waypoints"), index -> {
			tab = index;
			input.setText("");
			listSource = null;
			list.resetScroll();
		});
		this.primary = new Button("ui.config.create", Icon.PLUS, Button.Style.PRIMARY, this::primaryAction);
		this.saveProfile = new Button("ui.config.save", Icon.SAVE, Button.Style.SECONDARY, this::secondaryAction);
		this.clearDeaths = new Button("ui.config.clear_deaths", Icon.TRASH, Button.Style.SECONDARY, this::secondaryAction);
		input.onSubmit(value -> primaryAction());
	}

	public void refresh() {
		listSource = null;
	}

	private void notify(NotificationManager.Type type, String key, Object... args) {
		client.notifications().push(type, client.i18n().tr("ui.config.title"), client.i18n().tr(key, args));
	}

	private void report(ProfileManager.Outcome outcome, String successKey, String name) {
		if (outcome == ProfileManager.Outcome.OK) {
			notify(NotificationManager.Type.SUCCESS, successKey, name);
		} else {
			notify(NotificationManager.Type.ERROR, "ui.config.error." + outcome.name().toLowerCase(java.util.Locale.ROOT), name);
		}
		refresh();
	}

	private void primaryAction() {
		String value = input.text().strip();
		switch (tab) {
			case PROFILES -> {
				if (!value.isEmpty()) {
					report(client.profiles().create(value, false), "ui.config.created", value);
					input.setText("");
				}
			}
			case FRIENDS -> {
				if (client.friends().add(value)) {
					notify(NotificationManager.Type.SUCCESS, "ui.config.friend_added", value);
					input.setText("");
				} else if (!value.isEmpty()) {
					notify(NotificationManager.Type.WARNING, "ui.config.friend_invalid", value);
				}
			}
			default -> addWaypointHere(value);
		}
		refresh();
	}

	private void secondaryAction() {
		switch (tab) {
			case PROFILES -> {
				client.profiles().save();
				notify(NotificationManager.Type.SUCCESS, "ui.config.saved", client.profiles().active());
			}
			case WAYPOINTS -> {
				if (client.session().inWorld()) {
					client.waypoints().clearDeathPoints(client.session().worldKey());
				}
			}
			default -> {
			}
		}
		refresh();
	}

	private void addWaypointHere(String name) {
		LocalPlayer player = Minecraft.getInstance().player;
		if (player == null || !client.session().inWorld()) {
			notify(NotificationManager.Type.WARNING, "ui.config.waypoint_no_world");
			return;
		}
		String label = name.isEmpty() ? client.i18n().tr("ui.config.waypoint_default", client.waypoints().inWorld(client.session().worldKey()).size() + 1) : name;
		int color = WAYPOINT_COLORS[client.waypoints().all().size() % WAYPOINT_COLORS.length];
		if (client.waypoints().create(label, player.getBlockX(), player.getBlockY(), player.getBlockZ(), client.session().dimension(),
			client.session().worldKey(), color) != null) {
			input.setText("");
		}
	}

	private void rebuildIfNeeded(UiContext uiContext) {
		Object source;
		int revision;
		switch (tab) {
			case PROFILES -> {
				source = listSource == null ? new Object() : listSource;
				revision = client.profiles().active().hashCode();
			}
			case FRIENDS -> {
				source = client.friends().list();
				revision = 0;
			}
			default -> {
				source = client.session().worldKey();
				revision = client.waypoints().revision();
			}
		}
		if (source == listSource && revision == listRevision) {
			return;
		}
		listSource = source;
		listRevision = revision;
		List<Component> rows = new ArrayList<>();
		switch (tab) {
			case PROFILES -> {
				for (String name : client.profiles().list()) {
					rows.add(new ProfileRow(name));
				}
			}
			case FRIENDS -> {
				for (String name : client.friends().list()) {
					rows.add(new FriendRow(name));
				}
			}
			default -> {
				if (client.session().inWorld()) {
					for (Waypoint waypoint : client.waypoints().inWorld(client.session().worldKey())) {
						rows.add(new WaypointRow(waypoint));
					}
				}
			}
		}
		list.setChildren(rows);
	}

	@Override
	protected void draw(UiContext uiContext, float mouseX, float mouseY) {
		this.context = uiContext;
		Renderer2D renderer = uiContext.renderer();
		ThemeManager theme = uiContext.theme();
		rebuildIfNeeded(uiContext);
		tabs.setBounds(x, y, Math.min(width, 260), DesignTokens.CONTROL_HEIGHT + 4);
		tabs.render(uiContext, mouseX, mouseY);

		float rowY = y + tabs.height() + DesignTokens.SPACE_M;
		input.placeholder(switch (tab) {
			case PROFILES -> "ui.config.profile_name";
			case FRIENDS -> "ui.config.friend_name";
			default -> "ui.config.waypoint_name";
		});
		float buttonWidth = 74;
		boolean showSecondary = tab != FRIENDS;
		float inputWidth = width - buttonWidth - (showSecondary ? buttonWidth + 6 : 0) - 6;
		input.setBounds(x, rowY, inputWidth, 18);
		primary.setBounds(x + inputWidth + 6, rowY, buttonWidth, 18);
		Button secondary = secondary();
		if (secondary != null) {
			secondary.setBounds(x + inputWidth + buttonWidth + 12, rowY, buttonWidth, 18);
		}
		input.render(uiContext, mouseX, mouseY);
		primary.render(uiContext, mouseX, mouseY);
		if (secondary != null) {
			secondary.render(uiContext, mouseX, mouseY);
		}
		rowY += 18 + DesignTokens.SPACE_M;

		list.setBounds(x, rowY, width, y + height - rowY);
		if (list.children().isEmpty()) {
			String key = switch (tab) {
				case FRIENDS -> "ui.config.friends_empty";
				case WAYPOINTS -> client.session().inWorld() ? "ui.config.waypoints_empty" : "ui.config.waypoint_no_world";
				default -> "ui.config.profiles_empty";
			};
			renderer.text(uiContext.tr(key), x + width / 2f, rowY + 30, uiContext.text(DesignTokens.FONT_SMALL), theme.textSecondary(), Renderer2D.Align.CENTER);
		} else {
			list.render(uiContext, mouseX, mouseY);
		}
	}

	private Button secondary() {
		return switch (tab) {
			case PROFILES -> saveProfile;
			case WAYPOINTS -> clearDeaths;
			default -> null;
		};
	}

	@Override
	public boolean mouseClicked(UiContext uiContext, float mouseX, float mouseY, int button) {
		if (tabs.mouseClicked(uiContext, mouseX, mouseY, button) || input.mouseClicked(uiContext, mouseX, mouseY, button)
			|| primary.mouseClicked(uiContext, mouseX, mouseY, button)) {
			return true;
		}
		Button secondary = secondary();
		if (secondary != null && secondary.mouseClicked(uiContext, mouseX, mouseY, button)) {
			return true;
		}
		return list.mouseClicked(uiContext, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseScrolled(UiContext uiContext, float mouseX, float mouseY, double amount) {
		return list.mouseScrolled(uiContext, mouseX, mouseY, amount);
	}

	@Override
	public boolean mouseDragged(UiContext uiContext, float mouseX, float mouseY, int button) {
		return list.mouseDragged(uiContext, mouseX, mouseY, button);
	}

	@Override
	public boolean mouseReleased(UiContext uiContext, float mouseX, float mouseY, int button) {
		return list.mouseReleased(uiContext, mouseX, mouseY, button);
	}

	/** Base row: rounded card with a title and right-aligned action buttons. */
	private abstract class Row extends Component {
		protected final List<Button> actions = new ArrayList<>();

		@Override
		public float preferredHeight(UiContext uiContext, float availableWidth) {
			return 24;
		}

		protected void drawCard(UiContext uiContext, boolean highlighted) {
			ThemeManager theme = uiContext.theme();
			uiContext.renderer().rounded(x, y, width, height, DesignTokens.RADIUS_M, ColorUtil.lerp(theme.card(), theme.cardHover(), hover()));
			uiContext.renderer().outline(x, y, width, height, DesignTokens.RADIUS_M, 1, highlighted ? theme.accentMuted(120) : theme.border());
		}

		protected float layoutActions(UiContext uiContext, float mouseX, float mouseY) {
			float right = x + width - 5;
			for (int i = actions.size() - 1; i >= 0; i--) {
				Button action = actions.get(i);
				action.setBounds(right - 15, y + (height - 15) / 2f, 15, 15);
				action.render(uiContext, mouseX, mouseY);
				right -= 18;
			}
			return right;
		}

		@Override
		public boolean mouseClicked(UiContext uiContext, float mouseX, float mouseY, int button) {
			for (Button action : actions) {
				if (action.mouseClicked(uiContext, mouseX, mouseY, button)) {
					return true;
				}
			}
			return contains(mouseX, mouseY);
		}
	}

	private final class ProfileRow extends Row {
		private final String name;

		ProfileRow(String name) {
			this.name = name;
			boolean isDefault = name.equals(ProfileManager.DEFAULT);
			actions.add(Button.icon(Icon.CHECK, "ui.config.load", () -> report(client.profiles().load(name), "ui.config.loaded", name)));
			actions.add(Button.icon(Icon.COPY, "ui.config.duplicate", () -> Dialog.prompt(context, "ui.config.duplicate", name + " copy",
				ProfileManager.MAX_NAME_LENGTH, ProfileManager::isValidName, target -> report(client.profiles().duplicate(name, target), "ui.config.created", target))));
			if (!isDefault) {
				actions.add(Button.icon(Icon.EDIT, "ui.config.rename", () -> Dialog.prompt(context, "ui.config.rename", name,
					ProfileManager.MAX_NAME_LENGTH, ProfileManager::isValidName, target -> report(client.profiles().rename(name, target), "ui.config.renamed", target))));
				actions.add(Button.icon(Icon.TRASH, "ui.delete", () -> Dialog.confirm(context, "ui.config.delete_title",
					client.i18n().tr("ui.config.delete_message", name), true, () -> report(client.profiles().delete(name), "ui.config.deleted", name))));
			}
		}

		@Override
		protected void draw(UiContext uiContext, float mouseX, float mouseY) {
			boolean active = client.profiles().active().equals(name);
			drawCard(uiContext, active);
			float right = layoutActions(uiContext, mouseX, mouseY);
			Renderer2D renderer = uiContext.renderer();
			ThemeManager theme = uiContext.theme();
			float size = uiContext.text(DesignTokens.FONT_SMALL);
			Icon.FOLDER.draw(renderer, x + 8, y + (height - 9) / 2f, 9, active ? theme.accent() : theme.textSecondary());
			String label = renderer.ellipsize(name, size, FontManager.Weight.SEMIBOLD, right - x - 70);
			renderer.textMiddle(label, x + 22, y + height / 2f, size, theme.textPrimary(), FontManager.Weight.SEMIBOLD, Renderer2D.Align.LEFT);
			if (active) {
				float labelEnd = x + 22 + renderer.textWidth(label, size, FontManager.Weight.SEMIBOLD) + 6;
				String badge = uiContext.tr("ui.config.active");
				float badgeSize = uiContext.text(DesignTokens.FONT_CAPTION) * 0.9f;
				float badgeWidth = renderer.textWidth(badge, badgeSize, FontManager.Weight.SEMIBOLD) + 8;
				renderer.rounded(labelEnd, y + height / 2f - 5, badgeWidth, 10, 3, theme.accentMuted(45));
				renderer.textMiddle(badge, labelEnd + badgeWidth / 2f, y + height / 2f, badgeSize, theme.accent(), FontManager.Weight.SEMIBOLD, Renderer2D.Align.CENTER);
			}
		}
	}

	private final class FriendRow extends Row {
		private final String name;

		FriendRow(String name) {
			this.name = name;
			actions.add(Button.icon(Icon.TRASH, "ui.delete", () -> {
				client.friends().remove(name);
				refresh();
			}));
		}

		@Override
		protected void draw(UiContext uiContext, float mouseX, float mouseY) {
			drawCard(uiContext, false);
			layoutActions(uiContext, mouseX, mouseY);
			Renderer2D renderer = uiContext.renderer();
			ThemeManager theme = uiContext.theme();
			renderer.circle(x + 12, y + height / 2f, 5.5f, theme.success());
			renderer.textMiddle(name.substring(0, 1).toUpperCase(java.util.Locale.ROOT), x + 12, y + height / 2f, 6.5f,
				ColorUtil.readableTextOn(theme.success()), FontManager.Weight.SEMIBOLD, Renderer2D.Align.CENTER);
			renderer.textMiddle(name, x + 24, y + height / 2f, uiContext.text(DesignTokens.FONT_SMALL), theme.textPrimary());
		}
	}

	private final class WaypointRow extends Row {
		private final Waypoint waypoint;
		private final ColorSwatch swatch;
		private final Toggle visibleToggle;

		WaypointRow(Waypoint waypoint) {
			this.waypoint = waypoint;
			ColorSetting proxy = new ColorSetting("color", waypoint.color(), false);
			proxy.onChange(value -> client.waypoints().update(current().withColor(value.argb())));
			this.swatch = new ColorSwatch(proxy);
			this.visibleToggle = new Toggle(() -> current().visible(), value -> client.waypoints().update(current().withVisible(value)));
			actions.add(Button.icon(Icon.EDIT, "ui.config.rename", () -> Dialog.prompt(context, "ui.config.rename", current().name(),
				Waypoint.MAX_NAME_LENGTH, value -> !value.isBlank(), value -> client.waypoints().update(current().withName(value)))));
			actions.add(Button.icon(Icon.TRASH, "ui.delete", () -> client.waypoints().remove(waypoint.id())));
		}

		private Waypoint current() {
			for (Waypoint candidate : client.waypoints().all()) {
				if (candidate.id().equals(waypoint.id())) {
					return candidate;
				}
			}
			return waypoint;
		}

		@Override
		protected void draw(UiContext uiContext, float mouseX, float mouseY) {
			drawCard(uiContext, false);
			float right = layoutActions(uiContext, mouseX, mouseY);
			visibleToggle.setBounds(right - DesignTokens.TOGGLE_WIDTH - 2, y + (height - DesignTokens.TOGGLE_HEIGHT) / 2f,
				DesignTokens.TOGGLE_WIDTH, DesignTokens.TOGGLE_HEIGHT);
			visibleToggle.render(uiContext, mouseX, mouseY);
			swatch.setBounds(x + 6, y + (height - 10) / 2f, 14, 10);
			swatch.render(uiContext, mouseX, mouseY);
			Renderer2D renderer = uiContext.renderer();
			ThemeManager theme = uiContext.theme();
			Waypoint shown = current();
			float size = uiContext.text(DesignTokens.FONT_SMALL);
			String name = renderer.ellipsize(shown.name(), size, FontManager.Weight.SEMIBOLD, width * 0.35f);
			renderer.textMiddle(name, x + 26, y + height / 2f, size, theme.textPrimary(), FontManager.Weight.SEMIBOLD, Renderer2D.Align.LEFT);
			String coordinates = client.privacy().hideCoordinates() ? uiContext.tr("ui.profile.hidden")
				: shown.x() + ", " + shown.y() + ", " + shown.z();
			String dimension = shown.dimension().substring(shown.dimension().indexOf(':') + 1).replace('_', ' ');
			String details = coordinates + "  ·  " + dimension + (shown.kind() == Waypoint.Kind.DEATH ? "  ·  " + uiContext.tr("ui.config.death") : "");
			float detailsX = x + 30 + renderer.textWidth(name, size, FontManager.Weight.SEMIBOLD);
			renderer.textMiddle(renderer.ellipsize(details, uiContext.text(DesignTokens.FONT_CAPTION), FontManager.Weight.MEDIUM,
				right - DesignTokens.TOGGLE_WIDTH - 10 - detailsX), detailsX, y + height / 2f, uiContext.text(DesignTokens.FONT_CAPTION), theme.textSecondary());
		}

		@Override
		public boolean mouseClicked(UiContext uiContext, float mouseX, float mouseY, int button) {
			return swatch.mouseClicked(uiContext, mouseX, mouseY, button) || visibleToggle.mouseClicked(uiContext, mouseX, mouseY, button)
				|| super.mouseClicked(uiContext, mouseX, mouseY, button);
		}
	}
}
