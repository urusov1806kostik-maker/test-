package com.pitbike.network;

import com.pitbike.entity.PitbikeEntity;
import com.pitbike.entity.Trick;
import net.minecraft.network.FriendlyByteBuf;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.network.NetworkEvent;

import java.util.function.Supplier;

/** Client -> server: the rider pressed a trick key. */
public record TrickPacket(int trick) {
    public void encode(FriendlyByteBuf buf) {
        buf.writeVarInt(this.trick);
    }

    public static TrickPacket decode(FriendlyByteBuf buf) {
        return new TrickPacket(buf.readVarInt());
    }

    public void handle(Supplier<NetworkEvent.Context> context) {
        ServerPlayer player = context.get().getSender();
        Trick trick = Trick.byNetworkId(this.trick);
        if (player != null && trick != null && player.getVehicle() instanceof PitbikeEntity bike) {
            bike.tryStartTrick(player, trick);
        }
    }
}
