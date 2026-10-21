package com.pitbike.network;

import com.pitbike.PitbikeMod;
import net.minecraft.resources.ResourceLocation;
import net.minecraftforge.network.NetworkDirection;
import net.minecraftforge.network.NetworkRegistry;
import net.minecraftforge.network.simple.SimpleChannel;

public final class PitbikeNetwork {
    private static final String VERSION = "1";
    public static final SimpleChannel CHANNEL = NetworkRegistry.newSimpleChannel(
            new ResourceLocation(PitbikeMod.MOD_ID, "main"), () -> VERSION, VERSION::equals, VERSION::equals);

    private PitbikeNetwork() {
    }

    public static void register() {
        CHANNEL.messageBuilder(TrickPacket.class, 0, NetworkDirection.PLAY_TO_SERVER)
                .encoder(TrickPacket::encode)
                .decoder(TrickPacket::decode)
                .consumerMainThread(TrickPacket::handle)
                .add();
    }
}
