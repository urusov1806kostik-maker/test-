package com.pitbike;

import com.pitbike.item.PitbikeItem;
import net.minecraft.world.item.Item;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

public final class ModItems {
    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, PitbikeMod.MOD_ID);

    public static final RegistryObject<Item> PITBIKE = ITEMS.register("pitbike",
            () -> new PitbikeItem(new Item.Properties().stacksTo(1)));

    private ModItems() {
    }
}
