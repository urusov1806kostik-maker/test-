package dev.shadowvisuals.modules;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.module.ModuleManager;
import dev.shadowvisuals.modules.utility.RecordingMode;

/** The single place where every built-in module is registered, in sidebar display order. */
public final class ModuleCatalog {
	private ModuleCatalog() {
	}

	public static void registerAll(ShadowClient client) {
		ModuleManager modules = client.modules();
		modules.register(new RecordingMode());
	}
}
