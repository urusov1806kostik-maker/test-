package dev.shadowvisuals.event.events;

import net.minecraft.world.entity.Entity;

/** The local player attacked an entity (client-side observation only; nothing is sent by Shadow Visuals). */
public record AttackEntityEvent(Entity target) {
}
