package dev.nyxveravisuals.module;

import java.util.ArrayList;
import java.util.List;
import java.util.function.Consumer;

import dev.nyxveravisuals.event.Priority;
import dev.nyxveravisuals.event.Subscription;
import dev.nyxveravisuals.setting.BooleanSetting;
import dev.nyxveravisuals.setting.Configurable;
import dev.nyxveravisuals.setting.Keybind;
import dev.nyxveravisuals.setting.KeybindSetting;
import dev.nyxveravisuals.setting.ModeSetting;
import dev.nyxveravisuals.setting.SettingRegistry;

/**
 * Base of every feature. Event listeners declared with {@link #on} are subscribed only while the module is
 * enabled, so a disabled module costs nothing per frame. Enable/disable hooks are fail-safe: an exception
 * disables this module alone and is reported through the {@link ModuleHost}.
 */
public abstract class Module implements Configurable {
	public enum BindMode {
		TOGGLE,
		HOLD
	}

	private final String id;
	private final Category category;
	private final boolean enabledByDefault;
	private final SettingRegistry settings;
	private final KeybindSetting bind;
	private final ModeSetting<BindMode> bindMode;
	private final BooleanSetting hiddenFromList;
	private final List<ListenerSpec<?>> listenerSpecs = new ArrayList<>();
	private final List<Subscription> subscriptions = new ArrayList<>();

	private ModuleHost host;
	private boolean enabled;
	private boolean failed;

	protected Module(String id, Category category) {
		this(id, category, false);
	}

	protected Module(String id, Category category, boolean enabledByDefault) {
		if (!id.matches("[a-z0-9_]+")) {
			throw new IllegalArgumentException("Module id must be snake_case: " + id);
		}
		this.id = id;
		this.category = category;
		this.enabledByDefault = enabledByDefault;
		this.settings = new SettingRegistry("module." + id);
		this.bind = new KeybindSetting("bind", Keybind.NONE);
		this.bindMode = new ModeSetting<>("bind_mode", BindMode.TOGGLE);
		this.hiddenFromList = new BooleanSetting("hidden", false);
		// Reserved ids; the GUI renders these in the module footer instead of the generic list.
		settings.add(bind);
		settings.add(bindMode);
		settings.add(hiddenFromList);
	}

	/** True for the built-in settings every module has (bind, bind mode, hidden). */
	public final boolean isCoreSetting(Object node) {
		return node == bind || node == bindMode || node == hiddenFromList;
	}

	public final String id() {
		return id;
	}

	public final Category category() {
		return category;
	}

	public final String nameKey() {
		return "module." + id + ".name";
	}

	public final String descriptionKey() {
		return "module." + id + ".description";
	}

	@Override
	public final SettingRegistry settings() {
		return settings;
	}

	public final KeybindSetting bind() {
		return bind;
	}

	public final ModeSetting<BindMode> bindMode() {
		return bindMode;
	}

	public final BooleanSetting hiddenFromList() {
		return hiddenFromList;
	}

	/** Whether the module can be toggled by the user (HUD-only containers may opt out). */
	public boolean isToggleable() {
		return true;
	}

	/** Optional short status shown next to the name in the module list (e.g. current mode). */
	public String listSuffix() {
		return null;
	}

	public final boolean enabledByDefault() {
		return enabledByDefault;
	}

	public final boolean isEnabled() {
		return enabled;
	}

	public final boolean hasFailed() {
		return failed;
	}

	/** Declares an event listener that is active only while the module is enabled. */
	protected final <E> void on(Class<E> type, Consumer<E> handler) {
		on(type, Priority.NORMAL, handler);
	}

	protected final <E> void on(Class<E> type, Priority priority, Consumer<E> handler) {
		listenerSpecs.add(new ListenerSpec<>(type, priority, handler));
	}

	final void attach(ModuleHost moduleHost) {
		if (this.host != null) {
			throw new IllegalStateException("Module " + id + " is already registered");
		}
		this.host = moduleHost;
	}

	public final void toggle() {
		setEnabled(!enabled);
	}

	public final void setEnabled(boolean value) {
		if (value == enabled || host == null) {
			return;
		}
		if (value) {
			enable();
		} else {
			disable();
		}
	}

	private void enable() {
		failed = false;
		enabled = true;
		try {
			onEnable();
		} catch (Exception | LinkageError error) {
			enabled = false;
			failed = true;
			host.onModuleFailure(this, "enable", error);
			return;
		}
		for (ListenerSpec<?> spec : listenerSpecs) {
			subscriptions.add(spec.subscribe(host, this));
		}
		host.onModuleToggled(this, true);
	}

	private void disable() {
		for (Subscription subscription : subscriptions) {
			subscription.unsubscribe();
		}
		subscriptions.clear();
		enabled = false;
		try {
			onDisable();
		} catch (Exception | LinkageError error) {
			failed = true;
			host.onModuleFailure(this, "disable", error);
		}
		host.onModuleToggled(this, false);
	}

	/** Disables the module after a runtime failure (called by the manager's error handler). */
	final void fail() {
		if (enabled) {
			disable();
		}
		failed = true;
	}

	/** Restores defaults of all settings except the bind, which users rarely expect to lose. */
	public void resetSettings() {
		var keepBind = bind.get();
		settings.resetAll();
		bind.set(keepBind);
	}

	protected void onEnable() {
	}

	/** Must restore any client state this module changed. */
	protected void onDisable() {
	}

	@Override
	public String toString() {
		return "Module[" + id + "]";
	}

	private record ListenerSpec<E>(Class<E> type, Priority priority, Consumer<E> handler) {
		Subscription subscribe(ModuleHost host, Module owner) {
			return host.eventBus().subscribe(type, owner, priority, handler);
		}
	}
}
