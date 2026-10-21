package com.pitbike.item;

import com.pitbike.ModEntities;
import com.pitbike.entity.PitbikeEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.context.UseOnContext;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.gameevent.GameEvent;

public class PitbikeItem extends Item {
    public PitbikeItem(Properties properties) {
        super(properties);
    }

    @Override
    public InteractionResult useOn(UseOnContext context) {
        Level level = context.getLevel();
        if (!(level instanceof ServerLevel serverLevel)) {
            return InteractionResult.SUCCESS;
        }

        BlockPos clicked = context.getClickedPos();
        BlockPos pos = level.getBlockState(clicked).getCollisionShape(level, clicked).isEmpty()
                ? clicked : clicked.relative(context.getClickedFace());
        Player player = context.getPlayer();
        float yaw = player != null ? player.getYRot() : 0.0F;

        PitbikeEntity bike = new PitbikeEntity(ModEntities.PITBIKE.get(), level);
        bike.moveTo(pos.getX() + 0.5, pos.getY(), pos.getZ() + 0.5, yaw, 0.0F);
        bike.setYHeadRot(yaw);
        bike.setYBodyRot(yaw);
        if (!level.noCollision(bike, bike.getBoundingBox())) {
            return InteractionResult.FAIL;
        }

        ItemStack stack = context.getItemInHand();
        if (stack.hasCustomHoverName()) {
            bike.setCustomName(stack.getHoverName());
        }
        serverLevel.addFreshEntity(bike);
        level.gameEvent(player, GameEvent.ENTITY_PLACE, pos);
        if (player == null || !player.getAbilities().instabuild) {
            stack.shrink(1);
        }
        return InteractionResult.CONSUME;
    }
}
