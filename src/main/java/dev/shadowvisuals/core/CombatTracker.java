package dev.shadowvisuals.core;

import java.lang.ref.WeakReference;

import net.minecraft.client.Minecraft;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;

import dev.shadowvisuals.event.EventBus;
import dev.shadowvisuals.event.Priority;
import dev.shadowvisuals.event.events.AttackEntityEvent;
import dev.shadowvisuals.event.events.WorldLeaveEvent;

/**
 * Remembers the last entity the local player attacked (weakly referenced, cleared on world leave) for the
 * Target HUD and hit effects. Purely observational: it never attacks or sends anything.
 */
public final class CombatTracker {
	private WeakReference<LivingEntity> lastTarget = new WeakReference<>(null);
	private long lastAttackMillis;

	public CombatTracker(EventBus events) {
		events.subscribe(AttackEntityEvent.class, this, Priority.MONITOR, event -> {
			Entity target = event.target();
			if (target instanceof LivingEntity living) {
				lastTarget = new WeakReference<>(living);
				lastAttackMillis = System.currentTimeMillis();
			}
		});
		events.subscribe(WorldLeaveEvent.class, this, event -> clear());
	}

	public void clear() {
		lastTarget = new WeakReference<>(null);
		lastAttackMillis = 0;
	}

	/** Last attacked entity if it is still alive, in the current level and attacked within {@code timeoutMillis}. */
	public LivingEntity recentTarget(long timeoutMillis) {
		LivingEntity target = lastTarget.get();
		Minecraft minecraft = Minecraft.getInstance();
		if (target == null || minecraft.level == null || target.level() != minecraft.level || target.isRemoved() || !target.isAlive()) {
			return null;
		}
		return System.currentTimeMillis() - lastAttackMillis <= timeoutMillis ? target : null;
	}

	public long lastAttackMillis() {
		return lastAttackMillis;
	}
}
