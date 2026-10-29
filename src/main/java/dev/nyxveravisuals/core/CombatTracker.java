package dev.nyxveravisuals.core;

import java.lang.ref.WeakReference;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;

import net.minecraft.client.Minecraft;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;

import dev.nyxveravisuals.event.EventBus;
import dev.nyxveravisuals.event.Priority;
import dev.nyxveravisuals.event.events.AttackEntityEvent;
import dev.nyxveravisuals.event.events.WorldLeaveEvent;

/**
 * Remembers the last entity the local player attacked (weakly referenced, cleared on world leave) and counts
 * totem pops per entity from the "protected from death" entity event the server broadcasts, for the Target HUD
 * and hit effects. Purely observational: it never attacks or sends anything.
 */
public final class CombatTracker {
	private static final int MAX_TRACKED_POPS = 256;

	private WeakReference<LivingEntity> lastTarget = new WeakReference<>(null);
	private long lastAttackMillis;
	private final Map<UUID, Integer> totemPops = new LinkedHashMap<>(32, 0.75f, true) {
		@Override
		protected boolean removeEldestEntry(Map.Entry<UUID, Integer> eldest) {
			return size() > MAX_TRACKED_POPS;
		}
	};

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
		totemPops.clear();
	}

	/** Called (render thread) when an entity used a totem of undying. */
	public void onTotemPop(LivingEntity entity) {
		totemPops.merge(entity.getUUID(), 1, Integer::sum);
	}

	/** Totems this entity used since it was first seen, its last death or the last world change. */
	public int totemPops(LivingEntity entity) {
		if (entity.isDeadOrDying()) {
			totemPops.remove(entity.getUUID());
			return 0;
		}
		Integer pops = totemPops.get(entity.getUUID());
		return pops == null ? 0 : pops;
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
