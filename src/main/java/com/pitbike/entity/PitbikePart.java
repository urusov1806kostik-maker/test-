package com.pitbike.entity;

import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientGamePacketListener;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityDimensions;
import net.minecraft.world.entity.Pose;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraftforge.entity.PartEntity;

/** One hitbox of the pitbike. Damage and interaction are forwarded to the bike. */
public class PitbikePart extends PartEntity<PitbikeEntity> {
    public final String name;
    public final float damageMultiplier;
    /** Offset from the bike origin in blocks, bike facing +Z; y is the bottom of the box. */
    final double localX, localY, localZ;
    private final EntityDimensions size;

    public PitbikePart(PitbikeEntity parent, String name, float damageMultiplier,
                       double localX, double localY, double localZ, float width, float height) {
        super(parent);
        this.name = name;
        this.damageMultiplier = damageMultiplier;
        this.localX = localX;
        this.localY = localY;
        this.localZ = localZ;
        this.size = EntityDimensions.scalable(width, height);
        this.refreshDimensions();
    }

    @Override
    protected void defineSynchedData() {
    }

    @Override
    protected void readAdditionalSaveData(CompoundTag tag) {
    }

    @Override
    protected void addAdditionalSaveData(CompoundTag tag) {
    }

    @Override
    public boolean isPickable() {
        return true;
    }

    @Override
    public boolean hurt(DamageSource source, float amount) {
        return !this.isInvulnerableTo(source) && this.getParent().hurtPart(this, source, amount);
    }

    @Override
    public InteractionResult interact(Player player, InteractionHand hand) {
        return this.getParent().interact(player, hand);
    }

    @Override
    public ItemStack getPickResult() {
        return this.getParent().getPickResult();
    }

    @Override
    public boolean is(Entity entity) {
        return this == entity || this.getParent() == entity;
    }

    /** Lets the rider's crosshair pass through their own bike, like with any vehicle. */
    @Override
    public Entity getRootVehicle() {
        return this.getParent().getRootVehicle();
    }

    @Override
    public EntityDimensions getDimensions(Pose pose) {
        return this.size;
    }

    @Override
    public boolean shouldBeSaved() {
        return false;
    }

    @Override
    public Packet<ClientGamePacketListener> getAddEntityPacket() {
        throw new UnsupportedOperationException();
    }
}
