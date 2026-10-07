package dev.shadowvisuals.modules;

import dev.shadowvisuals.ShadowClient;
import dev.shadowvisuals.module.Module;

/** Lookup used by mixins: returns the module only while it is enabled, otherwise {@code null}. */
public final class Hooks {
	private Hooks() {
	}

	public static <M extends Module> M enabled(Class<M> type) {
		ShadowClient client = ShadowClient.get();
		if (client == null) {
			return null;
		}
		M module = client.modules().get(type);
		return module != null && module.isEnabled() ? module : null;
	}
}
