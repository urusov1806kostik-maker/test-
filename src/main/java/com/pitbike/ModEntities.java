package com.pitbike;

import com.pitbike.entity.PitbikeEntity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.MobCategory;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModEntities {
    public static final DeferredRegister<EntityType<?>> ENTITIES =
            DeferredRegister.create(ForgeRegistries.ENTITY_TYPES, PitbikeMod.MOD_ID);

    public static final RegistryObject<EntityType<PitbikeEntity>> PITBIKE = ENTITIES.register("pitbike",
            () -> EntityType.Builder.<PitbikeEntity>of(PitbikeEntity::new, MobCategory.MISC)
                    .sized(1.0F, 1.4F)
                    .clientTrackingRange(10)
                    .fireImmune()
                    .build("pitbike"));

    private ModEntities() {
    }
}
