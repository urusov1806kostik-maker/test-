package dev.shadowvisuals.module;

import dev.shadowvisuals.event.EventBus;

/** Services a module receives from its manager; keeps modules free of global lookups. */
public interface ModuleHost {
	EventBus eventBus();

	void onModuleToggled(Module module, boolean enabled);

	void onModuleFailure(Module module, String phase, Throwable error);
}
