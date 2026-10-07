package dev.shadowvisuals;

import java.nio.file.Path;

import net.minecraft.client.DeltaTracker;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;

import dev.shadowvisuals.animation.AnimationClock;
import dev.shadowvisuals.config.ClientPreferences;
import dev.shadowvisuals.config.ConfigManager;
import dev.shadowvisuals.config.ProfileContent;
import dev.shadowvisuals.config.ProfileManager;
import dev.shadowvisuals.core.ClientSettings;
import dev.shadowvisuals.core.Log;
import dev.shadowvisuals.core.SessionState;
import dev.shadowvisuals.core.UiSounds;
import dev.shadowvisuals.event.EventBus;
import dev.shadowvisuals.event.events.ClientTickEvent;
import dev.shadowvisuals.event.events.DeathEvent;
import dev.shadowvisuals.event.events.DimensionChangeEvent;
import dev.shadowvisuals.event.events.HudRenderEvent;
import dev.shadowvisuals.event.events.KeyInputEvent;
import dev.shadowvisuals.event.events.MouseButtonInputEvent;
import dev.shadowvisuals.event.events.ResourceReloadEvent;
import dev.shadowvisuals.event.events.RespawnEvent;
import dev.shadowvisuals.event.events.WorldJoinEvent;
import dev.shadowvisuals.event.events.WorldLeaveEvent;
import dev.shadowvisuals.friend.FriendManager;
import dev.shadowvisuals.hud.HudContext;
import dev.shadowvisuals.hud.HudManager;
import dev.shadowvisuals.hud.HudModule;
import dev.shadowvisuals.hud.NotificationRenderer;
import dev.shadowvisuals.i18n.Localization;
import dev.shadowvisuals.module.Module;
import dev.shadowvisuals.module.ModuleManager;
import dev.shadowvisuals.modules.ModuleCatalog;
import dev.shadowvisuals.modules.utility.RecordingMode;
import dev.shadowvisuals.notification.NotificationManager;
import dev.shadowvisuals.render.FrameState;
import dev.shadowvisuals.render.Renderer2D;
import dev.shadowvisuals.render.ShadowPipelines;
import dev.shadowvisuals.render.WorldProjection;
import dev.shadowvisuals.render.font.FontManager;
import dev.shadowvisuals.setting.Keybind;
import dev.shadowvisuals.theme.ThemeManager;
import dev.shadowvisuals.ui.screen.ScreenManager;
import dev.shadowvisuals.waypoint.WaypointManager;

/**
 * Service container and lifecycle owner of the client. Created once by {@link ShadowVisuals}; mixins reach
 * it through {@link #get()}, every other class receives what it needs explicitly.
 */
public final class ShadowClient {
	private static ShadowClient instance;

	private final EventBus events = new EventBus();
	private final Localization i18n = new Localization();
	private final ClientSettings settings = new ClientSettings();
	private final ThemeManager theme = new ThemeManager();
	private final ModuleManager modules = new ModuleManager(events);
	private final HudManager hud = new HudManager();
	private final FriendManager friends = new FriendManager();
	private final WaypointManager waypoints = new WaypointManager();
	private final NotificationManager notifications = new NotificationManager();
	private final FontManager fonts = new FontManager();
	private final Renderer2D renderer = new Renderer2D(fonts);
	private final WorldProjection projection = new WorldProjection();
	private final FrameState frame = new FrameState();
	private final SessionState session = new SessionState();
	private final UiSounds sounds = new UiSounds(settings);
	private final ConfigManager config;
	private final ProfileManager profiles;
	private final ClientPreferences preferences;
	private final NotificationRenderer notificationRenderer;
	private final ScreenManager screens;
	private boolean started;
	private final SessionState.Listener sessionListener = new SessionState.Listener() {
		@Override
		public void onDimensionChanged(String from, String to) {
			events.post(new DimensionChangeEvent(from, to));
		}

		@Override
		public void onRespawn() {
			events.post(RespawnEvent.INSTANCE);
		}

		@Override
		public void onDeath(int x, int y, int z, String dimension) {
			events.post(new DeathEvent(x, y, z, dimension));
		}
	};

	ShadowClient(Path configDirectory) {
		this.config = new ConfigManager(configDirectory);
		this.preferences = new ClientPreferences(settings, modules);
		this.profiles = new ProfileManager(config, new ProfileContent(modules, theme));
		this.notificationRenderer = new NotificationRenderer(this);
		this.screens = new ScreenManager(this);
	}

	public static ShadowClient get() {
		return instance;
	}

	static void setInstance(ShadowClient client) {
		instance = client;
	}

	// ------------------------------------------------------------------ startup

	void initialize() {
		events.setErrorHandler((owner, event, error) -> {
			if (!modules.handleListenerError(owner, event, error)) {
				Log.errorOnce("listener:" + owner, "Event listener {} failed on {}", owner, event.getClass().getSimpleName(), error);
			}
		});
		modules.addListener(new ModuleManager.Listener() {
			@Override
			public void onModuleToggled(Module module, boolean enabled) {
				if (started && settings.toggleNotifications.get() && !(module instanceof HudModule)) {
					notifications.push(enabled ? NotificationManager.Type.SUCCESS : NotificationManager.Type.INFO,
						i18n.tr(module.nameKey()), i18n.tr(enabled ? "notification.module_enabled" : "notification.module_disabled"), 1.6f);
				}
			}

			@Override
			public void onModuleFailed(Module module, String phase, Throwable error) {
				notifications.push(NotificationManager.Type.ERROR, i18n.tr(module.nameKey()), i18n.tr("notification.module_failed"), 5f);
			}
		});

		ModuleCatalog.registerAll(this);
		for (Module module : modules.all()) {
			if (module instanceof HudModule hudModule) {
				hud.register(hudModule);
			}
		}

		config.ensureRoot();
		config.register(preferences);
		config.register(friends);
		config.register(waypoints);
		config.load(preferences);
		config.load(friends);
		config.load(waypoints);
		profiles.initialize(preferences.activeProfile());

		Runnable profileDirty = () -> config.markDirty(profiles.content());
		modules.setDirtyHook(profileDirty);
		for (Module module : modules.all()) {
			module.settings().addChangeListener(profileDirty);
		}
		theme.settings().addChangeListener(profileDirty);
		settings.settings().addChangeListener(() -> {
			config.markDirty(preferences);
			applyClientSettings();
		});
		friends.setDirtyHook(() -> config.markDirty(friends));
		waypoints.setDirtyHook(() -> config.markDirty(waypoints));
		profiles.addListener(() -> {
			preferences.setActiveProfile(profiles.active());
			config.markDirty(preferences);
		});
		applyClientSettings();
		Log.info("Initialized with {} modules", modules.all().size());
	}

	/** Called once the game window and render system are ready. */
	void onClientStarted() {
		fonts.init();
		ShadowPipelines.invalidate();
		applyClientSettings();
		started = true;
		for (String file : config.drainProblems()) {
			notifications.push(NotificationManager.Type.WARNING, i18n.tr("notification.config_reset"), file, 6f);
		}
		if (!preferences.firstLaunchDone()) {
			notifications.push(NotificationManager.Type.INFO, i18n.tr("notification.welcome.title"),
				i18n.tr("notification.welcome.message", keyName(settings.guiKey.get())), 8f);
			preferences.setFirstLaunchDone(true);
			config.markDirty(preferences);
		}
	}

	void shutdown() {
		modules.disableAll();
		config.shutdown();
		fonts.close();
	}

	private void applyClientSettings() {
		Minecraft client = Minecraft.getInstance();
		String gameLanguage = client != null && client.getLanguageManager() != null ? client.getLanguageManager().getSelected() : null;
		i18n.select(settings.language.get(), gameLanguage);
		AnimationClock.global().setMode(settings.animations.get());
		theme.setHighContrast(settings.highContrast.get());
		fonts.setUseCustomFont(settings.customFont.get());
		notifications.setEnabled(settings.notifications.get());
		Log.setDebugEnabled(settings.debugMode.get());
	}

	// ------------------------------------------------------------------ lifecycle hooks

	void onTick(Minecraft client, boolean start) {
		if (start) {
			events.post(ClientTickEvent.PRE);
			return;
		}
		session.tick(client, sessionListener);
		events.post(ClientTickEvent.POST);
		config.tick();
	}

	void onJoin(Minecraft client) {
		session.onJoin(client);
		events.post(new WorldJoinEvent(session.worldKey()));
	}

	void onLeave() {
		modules.releaseHeldBinds();
		events.post(WorldLeaveEvent.INSTANCE);
		session.onLeave();
		projection.invalidate();
		config.flush();
	}

	void onResourcesReloaded() {
		String gameLanguage = Minecraft.getInstance().getLanguageManager().getSelected();
		i18n.select(settings.language.get(), gameLanguage);
		ShadowPipelines.invalidate();
		events.post(ResourceReloadEvent.INSTANCE);
	}

	/** Start of every rendered frame (before world and GUI). */
	public void onFrameStart() {
		AnimationClock.global().frame();
		frame.beginFrame();
	}

	/**
	 * Raw keyboard input from the keyboard handler mixin. Returns true when the key opened the ClickGUI;
	 * vanilla handling is then skipped so the same press does not reach the freshly opened screen.
	 */
	public boolean onKey(int key, int scancode, int action, int modifiers) {
		events.post(new KeyInputEvent(key, scancode, action, modifiers));
		Minecraft client = Minecraft.getInstance();
		if (action == 2) {
			return false;
		}
		boolean pressed = action == 1;
		if (pressed && settings.guiKey.get().matches(Keybind.Device.KEYBOARD, key)
			&& (client.screen == null || client.screen instanceof net.minecraft.client.gui.screens.TitleScreen)) {
			screens.openClickGui();
			return true;
		}
		if (client.screen == null && client.level != null) {
			modules.handleBind(Keybind.Device.KEYBOARD, key, pressed);
		}
		return false;
	}

	/** Raw mouse button input from the mouse handler mixin. Returns true when it opened the ClickGUI. */
	public boolean onMouseButton(int button, int action, int modifiers) {
		events.post(new MouseButtonInputEvent(button, action, modifiers));
		Minecraft client = Minecraft.getInstance();
		if (client.screen == null && client.level != null && action != 2) {
			if (action == 1 && settings.guiKey.get().matches(Keybind.Device.MOUSE, button)) {
				screens.openClickGui();
				return true;
			}
			modules.handleBind(Keybind.Device.MOUSE, button, action == 1);
		}
		return false;
	}

	/** HUD pass registered after all vanilla HUD layers. */
	void renderHud(GuiGraphics graphics, DeltaTracker deltaTracker) {
		Minecraft client = Minecraft.getInstance();
		renderer.begin(graphics);
		float width = graphics.guiWidth();
		float height = graphics.guiHeight();
		float partialTick = deltaTracker.getGameTimeDeltaPartialTick(false);
		boolean editing = client.screen instanceof dev.shadowvisuals.ui.screen.HudEditorScreen;
		if (!client.options.hideGui || editing) {
			hud.render(new HudContext(renderer, theme, i18n, partialTick, width, height, editing, privacy()));
			events.post(new HudRenderEvent(renderer, deltaTracker, partialTick, width, height));
		}
		if (client.screen == null) {
			notificationRenderer.render(renderer, width, height);
		}
	}

	public HudContext.Privacy privacy() {
		RecordingMode recording = modules.get(RecordingMode.class);
		return recording != null && recording.isEnabled() ? recording.privacy() : HudContext.Privacy.NONE;
	}

	public String keyName(Keybind bind) {
		return dev.shadowvisuals.ui.KeyNames.name(bind, i18n);
	}

	// ------------------------------------------------------------------ accessors

	public EventBus events() {
		return events;
	}

	public Localization i18n() {
		return i18n;
	}

	public ClientSettings settings() {
		return settings;
	}

	public ThemeManager theme() {
		return theme;
	}

	public ModuleManager modules() {
		return modules;
	}

	public HudManager hud() {
		return hud;
	}

	public FriendManager friends() {
		return friends;
	}

	public WaypointManager waypoints() {
		return waypoints;
	}

	public NotificationManager notifications() {
		return notifications;
	}

	public NotificationRenderer notificationRenderer() {
		return notificationRenderer;
	}

	public FontManager fonts() {
		return fonts;
	}

	public Renderer2D renderer() {
		return renderer;
	}

	public WorldProjection projection() {
		return projection;
	}

	public FrameState frame() {
		return frame;
	}

	public SessionState session() {
		return session;
	}

	public UiSounds sounds() {
		return sounds;
	}

	public ConfigManager config() {
		return config;
	}

	public ProfileManager profiles() {
		return profiles;
	}

	public ClientPreferences preferences() {
		return preferences;
	}

	public ScreenManager screens() {
		return screens;
	}

	/** Restores every setting, module, HUD position and the theme of the current profile. */
	public void resetEverything() {
		modules.resetAll();
		theme.reset();
		hud.resetPositions();
		settings.settings().resetAll();
		config.markDirty(profiles.content());
		config.markDirty(preferences);
	}
}
