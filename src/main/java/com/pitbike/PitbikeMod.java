package com.pitbike;

import com.pitbike.entity.PitbikeEntity;
import net.minecraft.world.item.CreativeModeTabs;
import net.minecraftforge.event.BuildCreativeModeTabContentsEvent;
import net.minecraftforge.event.entity.EntityAttributeCreationEvent;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;

@Mod(PitbikeMod.MOD_ID)
public class PitbikeMod {
    public static final String MOD_ID = "pitbike";

    public PitbikeMod() {
        IEventBus bus = FMLJavaModLoadingContext.get().getModEventBus();
        ModEntities.ENTITIES.register(bus);
        ModItems.ITEMS.register(bus);
        bus.addListener(this::onAttributes);
        bus.addListener(this::onCreativeTab);
    }

    private void onAttributes(EntityAttributeCreationEvent event) {
        event.put(ModEntities.PITBIKE.get(), PitbikeEntity.createAttributes().build());
    }

    private void onCreativeTab(BuildCreativeModeTabContentsEvent event) {
        if (event.getTabKey() == CreativeModeTabs.TOOLS_AND_UTILITIES) {
            event.accept(ModItems.PITBIKE);
        }
    }
}
