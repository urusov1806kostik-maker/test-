package dev.nyxveravisuals.event.events;

import net.minecraft.world.entity.Entity;

/** The local player attacked an entity (client-side observation only; nothing is sent by NyxveraVisuals). */
public record AttackEntityEvent(Entity target) {
}
