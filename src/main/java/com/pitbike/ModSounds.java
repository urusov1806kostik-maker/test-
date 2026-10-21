package com.pitbike;

import net.minecraft.resources.ResourceLocation;
import net.minecraft.sounds.SoundEvent;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModSounds {
    public static final DeferredRegister<SoundEvent> SOUNDS =
            DeferredRegister.create(ForgeRegistries.SOUND_EVENTS, PitbikeMod.MOD_ID);

    public static final RegistryObject<SoundEvent> ENGINE = SOUNDS.register("engine",
            () -> SoundEvent.createVariableRangeEvent(new ResourceLocation(PitbikeMod.MOD_ID, "engine")));

    private ModSounds() {
    }
}
