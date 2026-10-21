package com.pitbike.client;

import com.mojang.blaze3d.platform.InputConstants;
import com.pitbike.PitbikeMod;
import com.pitbike.entity.PitbikeEntity;
import com.pitbike.entity.Trick;
import com.pitbike.network.PitbikeNetwork;
import com.pitbike.network.TrickPacket;
import net.minecraft.client.KeyMapping;
import net.minecraft.client.Minecraft;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.event.TickEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

import java.util.EnumMap;
import java.util.Map;

/** Trick keys, only used while airborne on a pitbike. */
@Mod.EventBusSubscriber(modid = PitbikeMod.MOD_ID, value = Dist.CLIENT)
public final class PitbikeKeys {
    public static final String CATEGORY = "key.categories.pitbike";
    public static final Map<Trick, KeyMapping> TRICKS = new EnumMap<>(Trick.class);

    static {
        add(Trick.ONE_HANDER, InputConstants.KEY_Z);
        add(Trick.NO_HANDER, InputConstants.KEY_X);
        add(Trick.SUPERMAN, InputConstants.KEY_C);
        add(Trick.BACKFLIP, InputConstants.KEY_V);
        add(Trick.SPIN, InputConstants.KEY_B);
    }

    private PitbikeKeys() {
    }

    private static void add(Trick trick, int key) {
        TRICKS.put(trick, new KeyMapping("key.pitbike." + trick.id, key, CATEGORY));
    }

    @SubscribeEvent
    public static void onClientTick(TickEvent.ClientTickEvent event) {
        if (event.phase != TickEvent.Phase.END) {
            return;
        }
        Minecraft mc = Minecraft.getInstance();
        boolean canTrick = mc.player != null && mc.player.getVehicle() instanceof PitbikeEntity bike && !bike.onGround();
        for (Map.Entry<Trick, KeyMapping> entry : TRICKS.entrySet()) {
            while (entry.getValue().consumeClick()) {
                if (canTrick) {
                    PitbikeNetwork.CHANNEL.sendToServer(new TrickPacket(entry.getKey().networkId()));
                }
            }
        }
    }
}
