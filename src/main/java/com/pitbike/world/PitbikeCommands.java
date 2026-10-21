package com.pitbike.world;

import com.pitbike.PitbikeMod;
import net.minecraft.commands.Commands;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.server.level.ServerPlayer;
import net.minecraftforge.event.RegisterCommandsEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = PitbikeMod.MOD_ID)
public final class PitbikeCommands {
    private PitbikeCommands() {
    }

    /** /pitbike city — builds the stunt city around you and puts you at the start. */
    @SubscribeEvent
    public static void register(RegisterCommandsEvent event) {
        event.getDispatcher().register(Commands.literal("pitbike")
                .requires(source -> source.hasPermission(2))
                .then(Commands.literal("city").executes(context -> {
                    ServerPlayer player = context.getSource().getPlayerOrException();
                    BlockPos origin = player.blockPosition().offset(-StuntCityBuilder.SIZE / 2, -1, -StuntCityBuilder.SIZE / 2);
                    StuntCityBuilder.build(player.serverLevel(), origin);
                    BlockPos start = StuntCityBuilder.startPoint(origin);
                    player.teleportTo(player.serverLevel(), start.getX() + 0.5, start.getY(), start.getZ() + 0.5, -90.0F, 0.0F);
                    context.getSource().sendSuccess(() -> Component.translatable("command.pitbike.city"), true);
                    return 1;
                })));
    }
}
