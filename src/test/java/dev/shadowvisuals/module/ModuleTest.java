package dev.shadowvisuals.module;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicInteger;

import com.google.gson.JsonObject;

import org.junit.jupiter.api.Test;

import dev.shadowvisuals.event.EventBus;
import dev.shadowvisuals.modules.funtime.ItemBinds;
import dev.shadowvisuals.setting.Keybind;
import dev.shadowvisuals.setting.NumberSetting;

class ModuleTest {
	record Ping(int value) {
	}

	static final class CountingModule extends Module {
		final AtomicInteger received = new AtomicInteger();
		final NumberSetting power = settings().add(new NumberSetting("power", 1, 0, 10, 1));
		boolean throwOnEvent;
		int enables;
		int disables;

		CountingModule(String id) {
			super(id, Category.VISUAL);
			on(Ping.class, ping -> {
				if (throwOnEvent) {
					throw new IllegalStateException("boom");
				}
				received.addAndGet(ping.value());
			});
		}

		@Override
		protected void onEnable() {
			enables++;
		}

		@Override
		protected void onDisable() {
			disables++;
		}
	}

	static final class BrokenModule extends Module {
		BrokenModule() {
			super("broken", Category.UTILITY);
		}

		@Override
		protected void onEnable() {
			throw new IllegalStateException("cannot enable");
		}
	}

	private static ModuleManager manager(EventBus bus) {
		ModuleManager manager = new ModuleManager(bus);
		bus.setErrorHandler((owner, event, error) -> manager.handleListenerError(owner, event, error));
		return manager;
	}

	@Test
	void listenersOnlyActiveWhileEnabled() {
		EventBus bus = new EventBus();
		ModuleManager manager = manager(bus);
		CountingModule module = manager.register(new CountingModule("counter"));

		bus.post(new Ping(1));
		assertEquals(0, module.received.get());
		module.setEnabled(true);
		bus.post(new Ping(2));
		module.setEnabled(false);
		bus.post(new Ping(4));
		assertEquals(2, module.received.get());
		assertEquals(1, module.enables);
		assertEquals(1, module.disables);
	}

	@Test
	void crashingListenerDisablesOnlyItsModule() {
		EventBus bus = new EventBus();
		ModuleManager manager = manager(bus);
		CountingModule bad = manager.register(new CountingModule("bad"));
		CountingModule good = manager.register(new CountingModule("good"));
		List<String> failures = new ArrayList<>();
		manager.addListener(new ModuleManager.Listener() {
			@Override
			public void onModuleFailed(Module module, String phase, Throwable error) {
				failures.add(module.id() + ":" + phase);
			}
		});
		bad.throwOnEvent = true;
		bad.setEnabled(true);
		good.setEnabled(true);

		bus.post(new Ping(3));
		assertFalse(bad.isEnabled());
		assertTrue(bad.hasFailed());
		assertTrue(good.isEnabled());
		assertEquals(3, good.received.get());
		assertEquals(List.of("bad:event"), failures);
	}

	@Test
	void failingEnableKeepsModuleOff() {
		ModuleManager manager = manager(new EventBus());
		BrokenModule broken = manager.register(new BrokenModule());
		broken.setEnabled(true);
		assertFalse(broken.isEnabled());
		assertTrue(broken.hasFailed());
	}

	@Test
	void bindsToggleAndHold() {
		ModuleManager manager = manager(new EventBus());
		CountingModule toggle = manager.register(new CountingModule("toggle"));
		CountingModule hold = manager.register(new CountingModule("hold"));
		toggle.bind().set(Keybind.key(70));
		hold.bind().set(Keybind.key(71));
		hold.bindMode().set(Module.BindMode.HOLD);

		manager.handleBind(Keybind.Device.KEYBOARD, 70, true);
		manager.handleBind(Keybind.Device.KEYBOARD, 70, false);
		assertTrue(toggle.isEnabled());
		manager.handleBind(Keybind.Device.KEYBOARD, 71, true);
		assertTrue(hold.isEnabled());
		manager.handleBind(Keybind.Device.KEYBOARD, 71, false);
		assertFalse(hold.isEnabled());
	}

	@Test
	void persistenceRoundTrip() {
		ModuleManager manager = manager(new EventBus());
		CountingModule module = manager.register(new CountingModule("persist"));
		module.setEnabled(true);
		module.power.set(7.0);
		module.bind().set(Keybind.key(82));
		JsonObject json = manager.toJson();

		ModuleManager other = manager(new EventBus());
		CountingModule copy = other.register(new CountingModule("persist"));
		other.load(json);
		assertTrue(copy.isEnabled());
		assertEquals(7.0, copy.power.get());
		assertEquals(Keybind.key(82), copy.bind().get());

		other.load(new JsonObject());
		assertFalse(copy.isEnabled());
		assertEquals(1.0, copy.power.get());
	}

	@Test
	void itemBindsStartUnboundAndPersist() {
		ModuleManager manager = manager(new EventBus());
		ItemBinds binds = manager.register(new ItemBinds(null));
		for (ItemBinds.Item item : ItemBinds.Item.values()) {
			assertEquals(Keybind.NONE, binds.bind(item).get());
		}
		binds.bind(ItemBinds.Item.DISORIENTATION).set(Keybind.key(88));
		binds.bind(ItemBinds.Item.LAYER).set(Keybind.mouse(4));
		JsonObject json = manager.toJson();

		ModuleManager other = manager(new EventBus());
		ItemBinds copy = other.register(new ItemBinds(null));
		other.load(json);
		assertEquals(Keybind.key(88), copy.bind(ItemBinds.Item.DISORIENTATION).get());
		assertEquals(Keybind.mouse(4), copy.bind(ItemBinds.Item.LAYER).get());
		assertEquals(Keybind.NONE, copy.bind(ItemBinds.Item.TRAP).get());
		assertTrue(copy.enabledByDefault());
		assertEquals("★ явная пыль", ItemBinds.normalize("§6★  Явная   Пыль "));
	}

	@Test
	void searchMatchesNameFirst() {
		ModuleManager manager = manager(new EventBus());
		manager.register(new CountingModule("alpha"));
		manager.register(new CountingModule("beta"));
		List<Module> result = manager.search("ALP", key -> key.contains("beta.description") ? "mentions alpha" : key);
		assertEquals(List.of("alpha", "beta"), result.stream().map(Module::id).toList());
	}
}
