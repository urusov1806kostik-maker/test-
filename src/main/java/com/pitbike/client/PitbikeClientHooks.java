package com.pitbike.client;

import com.pitbike.entity.PitbikeEntity;
import net.minecraft.client.Minecraft;

import java.util.Map;
import java.util.WeakHashMap;

/** Client-side per-bike effects, called from the bike's client tick. */
public final class PitbikeClientHooks {
    private static final Map<PitbikeEntity, EngineSound> ENGINE_SOUNDS = new WeakHashMap<>();

    private PitbikeClientHooks() {
    }

    /** Keeps the engine sound running while someone rides the bike. */
    public static void tickBike(PitbikeEntity bike) {
        EngineSound sound = ENGINE_SOUNDS.get(bike);
        if (sound != null && (bike.tickCount % 10 != 0 || Minecraft.getInstance().getSoundManager().isActive(sound))) {
            return;
        }
        sound = new EngineSound(bike);
        ENGINE_SOUNDS.put(bike, sound);
        Minecraft.getInstance().getSoundManager().play(sound);
    }
}
