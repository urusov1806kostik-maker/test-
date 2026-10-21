package com.pitbike.entity;

import com.pitbike.ModItems;
import com.pitbike.client.PitbikeClientHooks;
import net.minecraft.core.particles.ParticleTypes;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.Mth;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.damagesource.DamageSource;
import net.minecraft.world.effect.MobEffectInstance;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.EntityType;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.entity.Mob;
import net.minecraft.world.entity.ai.attributes.AttributeSupplier;
import net.minecraft.world.entity.ai.attributes.Attributes;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.GameRules;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.gameevent.GameEvent;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.entity.PartEntity;
import net.minecraftforge.fml.DistExecutor;
import org.jetbrains.annotations.Nullable;

import java.util.ArrayList;
import java.util.List;

public class PitbikeEntity extends Mob {
    /** Hitbox layout in model pixels (bike facing +Z): name, damage multiplier, min xyz, max xyz. */
    private static final PartDef[] PART_DEFS = {
            new PartDef("front_wheel", 0.75F, -1.5, 0.0, 6.3, 1.5, 13.6, 19.9),
            new PartDef("rear_wheel", 0.75F, -1.6, 0.0, -19.2, 1.6, 13.2, -6.0),
            new PartDef("swingarm", 1.0F, -2.8, 6.1, -12.7, 2.8, 10.0, -1.6),
            new PartDef("shock", 1.0F, -0.7, 10.1, -7.8, 0.7, 17.1, -3.0),
            new PartDef("engine", 1.5F, -2.7, 8.3, -6.3, 2.7, 17.1, 3.8),
            new PartDef("frame", 1.0F, -2.0, 7.7, 3.2, 2.0, 22.4, 7.6),
            new PartDef("frame", 1.0F, -2.0, 10.8, -10.6, 2.0, 20.0, -6.3),
            new PartDef("seat", 1.0F, -2.4, 16.8, -17.4, 2.4, 22.9, 1.5),
            new PartDef("tank", 1.5F, -2.7, 16.1, 1.6, 2.7, 21.7, 6.9),
            new PartDef("fork", 1.0F, -2.7, 6.3, 6.2, 2.7, 23.5, 13.9),
            new PartDef("fender", 1.0F, -2.1, 14.8, 13.9, 2.1, 18.3, 19.4),
            new PartDef("handlebar", 1.0F, -6.9, 22.9, 5.4, 6.9, 25.9, 7.6),
            new PartDef("exhaust", 1.0F, -3.7, 16.5, -14.3, -1.6, 20.1, -7.0),
    };
    /** Smallest hitbox side, in model pixels. */
    private static final double MIN_BOX = 4.0;

    private static final double SEAT_HEIGHT = 1.02;
    private static final double SEAT_Z = -0.45;
    private static final float ACCELERATION = 0.04F;
    private static final float BRAKING = 0.12F;
    private static final float COASTING = 0.025F;
    private static final float REVERSE_LIMIT = 0.3F;
    private static final float TURN_SPEED = 5.0F;
    /** "ride" spins the wheels 1.5 turns per second, which rolls 4 blocks on a 0.425 block radius wheel. */
    private static final float RIDE_ANIM_SECONDS_PER_BLOCK = 0.25F;
    private static final float LEAN_PER_TURN = 6.0F;
    private static final float MAX_LEAN = 30.0F;
    /** Silencer outlet in model pixels. */
    private static final Vec3 EXHAUST = new Vec3(-2.7, 19.3, -14.4).scale(1.0 / 16.0);

    private final PitbikePart[] parts;
    private float throttle;
    private float deltaYaw;
    // Client-only visual state.
    /** "ride" animation clock in seconds; it follows the distance driven, so the wheels match the ground. */
    private float rideAnimTime;
    private float rideAnimTimeO;
    /** Signed speed along the bike's facing, blocks per tick. */
    private float drivingSpeed;
    private float lean;
    private float leanO;

    public PitbikeEntity(EntityType<? extends PitbikeEntity> type, Level level) {
        super(type, level);
        this.parts = createParts();
        this.setId(ENTITY_COUNTER.getAndAdd(this.parts.length + 1) + 1);
        this.setMaxUpStep(1.0F);
        this.setPersistenceRequired();
    }

    public static AttributeSupplier.Builder createAttributes() {
        return Mob.createMobAttributes()
                .add(Attributes.MAX_HEALTH, 20.0)
                .add(Attributes.MOVEMENT_SPEED, 0.3)
                .add(Attributes.KNOCKBACK_RESISTANCE, 1.0);
    }

    private PitbikePart[] createParts() {
        List<PitbikePart> list = new ArrayList<>();
        for (PartDef def : PART_DEFS) {
            // Hitboxes are axis-aligned squares, so long parts get split into a row of boxes.
            double sizeX = def.maxX - def.minX;
            double sizeZ = def.maxZ - def.minZ;
            boolean alongX = sizeX > sizeZ;
            double length = Math.max(sizeX, sizeZ);
            double thickness = Math.max(Math.min(sizeX, sizeZ), MIN_BOX);
            int count = Math.max(1, (int) Math.round(length / thickness));
            double step = length / count;
            float side = (float) (Math.max(step, thickness) / 16.0);
            float height = (float) (Math.max(def.maxY - def.minY, MIN_BOX) / 16.0);
            for (int i = 0; i < count; i++) {
                double x = alongX ? def.minX + step * (i + 0.5) : (def.minX + def.maxX) / 2.0;
                double z = alongX ? (def.minZ + def.maxZ) / 2.0 : def.minZ + step * (i + 0.5);
                list.add(new PitbikePart(this, def.name, def.damageMultiplier,
                        x / 16.0, def.minY / 16.0, z / 16.0, side, height));
            }
        }
        return list.toArray(new PitbikePart[0]);
    }

    @Override
    public void setId(int id) {
        super.setId(id);
        if (this.parts != null) {
            for (int i = 0; i < this.parts.length; i++) {
                this.parts[i].setId(id + i + 1);
            }
        }
    }

    @Override
    public boolean isMultipartEntity() {
        return true;
    }

    @Override
    public PartEntity<?>[] getParts() {
        return this.parts;
    }

    @Override
    public void tick() {
        this.deltaYaw = 0.0F;
        super.tick();
        this.yBodyRot = this.getYRot();
        this.yHeadRot = this.getYRot();
        this.updateParts();

        if (this.level().isClientSide) {
            this.clientTick();
        }
    }

    private void clientTick() {
        float yaw = this.getYRot() * Mth.DEG_TO_RAD;
        double forward = -(this.getX() - this.xo) * Mth.sin(yaw) + (this.getZ() - this.zo) * Mth.cos(yaw);
        this.drivingSpeed = Mth.lerp(0.5F, this.drivingSpeed, (float) forward);

        this.rideAnimTimeO = this.rideAnimTime;
        if (this.isVehicle()) {
            this.rideAnimTime += this.drivingSpeed * RIDE_ANIM_SECONDS_PER_BLOCK;
        }

        this.leanO = this.lean;
        float turn = Mth.wrapDegrees(this.getYRot() - this.yRotO);
        float targetLean = this.isVehicle()
                ? Mth.clamp(turn * Math.abs(this.drivingSpeed) * LEAN_PER_TURN, -MAX_LEAN, MAX_LEAN) : 0.0F;
        this.lean = Mth.lerp(0.25F, this.lean, targetLean);

        if (this.isVehicle()) {
            this.spawnExhaustSmoke();
            DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () -> PitbikeClientHooks.tickBike(this));
        }
    }

    private void spawnExhaustSmoke() {
        if (this.random.nextFloat() > 0.3F + Math.abs(this.drivingSpeed)) {
            return;
        }
        Vec3 pos = EXHAUST.yRot(-this.getYRot() * Mth.DEG_TO_RAD).add(this.position());
        Vec3 back = new Vec3(0.0, 0.01, -0.04 - Math.max(this.drivingSpeed, 0.0F) * 0.2)
                .yRot(-this.getYRot() * Mth.DEG_TO_RAD);
        this.level().addParticle(ParticleTypes.SMOKE, pos.x, pos.y, pos.z, back.x, back.y, back.z);
    }

    private void updateParts() {
        float yaw = this.getYRot() * Mth.DEG_TO_RAD;
        float sin = Mth.sin(yaw);
        float cos = Mth.cos(yaw);
        for (PitbikePart part : this.parts) {
            double x = this.getX() + part.localX * cos - part.localZ * sin;
            double y = this.getY() + part.localY;
            double z = this.getZ() + part.localX * sin + part.localZ * cos;
            part.xo = part.getX();
            part.yo = part.getY();
            part.zo = part.getZ();
            part.xOld = part.xo;
            part.yOld = part.yo;
            part.zOld = part.zo;
            part.setPos(x, y, z);
        }
    }

    public float getRideAnimTime(float partialTick) {
        return Mth.lerp(partialTick, this.rideAnimTimeO, this.rideAnimTime);
    }

    /** Client only: roll angle in degrees, negative leans left. */
    public float getLean(float partialTick) {
        return Mth.lerp(partialTick, this.leanO, this.lean);
    }

    /** Client only: signed speed along the bike's facing, blocks per tick. */
    public float getDrivingSpeed() {
        return this.drivingSpeed;
    }

    // ---- Riding ----

    @Override
    protected InteractionResult mobInteract(Player player, InteractionHand hand) {
        if (player.isSecondaryUseActive() || this.isVehicle()) {
            return InteractionResult.PASS;
        }
        if (!this.level().isClientSide) {
            return player.startRiding(this) ? InteractionResult.CONSUME : InteractionResult.PASS;
        }
        return InteractionResult.SUCCESS;
    }

    @Nullable
    @Override
    public LivingEntity getControllingPassenger() {
        return this.getFirstPassenger() instanceof Player player ? player : null;
    }

    @Override
    protected Vec3 getRiddenInput(Player player, Vec3 travelVector) {
        float target = player.zza > 0 ? 1.0F : player.zza < 0 ? -REVERSE_LIMIT : 0.0F;
        float rate;
        if (target == 0.0F) {
            rate = COASTING;
        } else if (this.throttle != 0.0F && Math.signum(target) != Math.signum(this.throttle)) {
            rate = BRAKING;
        } else {
            rate = ACCELERATION;
        }
        this.throttle = Mth.approach(this.throttle, target, rate);
        return new Vec3(0.0, 0.0, this.throttle);
    }

    @Override
    protected void tickRidden(Player player, Vec3 travelVector) {
        super.tickRidden(player, travelVector);
        if (!this.isControlledByLocalInstance()) {
            return;
        }
        // Steering only works while rolling, and flips when reversing.
        float grip = Mth.clamp(Math.abs(this.throttle) * 3.0F, 0.0F, 1.0F);
        this.deltaYaw = -player.xxa * TURN_SPEED * grip * Math.signum(this.throttle);
        this.setYRot(this.getYRot() + this.deltaYaw);
        this.yBodyRot = this.getYRot();
        this.yHeadRot = this.getYRot();
    }

    @Override
    protected float getRiddenSpeed(Player player) {
        return (float) this.getAttributeValue(Attributes.MOVEMENT_SPEED);
    }

    @Override
    public double getPassengersRidingOffset() {
        return SEAT_HEIGHT;
    }

    @Override
    protected void positionRider(Entity passenger, Entity.MoveFunction moveFunction) {
        if (!this.hasPassenger(passenger)) {
            return;
        }
        Vec3 seat = new Vec3(0.0, 0.0, SEAT_Z).yRot(-this.getYRot() * Mth.DEG_TO_RAD);
        double y = this.getY() + this.getPassengersRidingOffset() + passenger.getMyRidingOffset();
        moveFunction.accept(passenger, this.getX() + seat.x, y, this.getZ() + seat.z);
        passenger.setYRot(passenger.getYRot() + this.deltaYaw);
        passenger.setYHeadRot(passenger.getYHeadRot() + this.deltaYaw);
        this.clampRotation(passenger);
    }

    @Override
    public void onPassengerTurned(Entity passenger) {
        this.clampRotation(passenger);
    }

    private void clampRotation(Entity passenger) {
        passenger.setYBodyRot(this.getYRot());
        float diff = Mth.wrapDegrees(passenger.getYRot() - this.getYRot());
        float clamped = Mth.clamp(diff, -105.0F, 105.0F);
        passenger.yRotO += clamped - diff;
        passenger.setYRot(passenger.getYRot() + clamped - diff);
        passenger.setYHeadRot(passenger.getYRot());
    }

    @Override
    protected void removePassenger(Entity passenger) {
        super.removePassenger(passenger);
        this.throttle = 0.0F;
    }

    // ---- Damage ----

    @Override
    public boolean hurt(DamageSource source, float amount) {
        return this.hurtPart(null, source, amount);
    }

    public boolean hurtPart(@Nullable PitbikePart part, DamageSource source, float amount) {
        if (this.level().isClientSide || this.isRemoved() || this.isInvulnerableTo(source)) {
            return false;
        }
        if (source.getEntity() instanceof Player player && player.getAbilities().instabuild) {
            this.ejectPassengers();
            this.discard();
            return true;
        }
        // Explosions and sweeps can hit several hitboxes at once; count it once.
        if (this.invulnerableTime > 0) {
            return false;
        }
        this.invulnerableTime = 10;

        float damage = amount * (part != null ? part.damageMultiplier : 1.0F);
        this.setHealth(this.getHealth() - damage);
        this.markHurt();
        this.level().broadcastDamageEvent(this, source);
        this.gameEvent(GameEvent.ENTITY_DAMAGE, source.getEntity());

        if (this.getHealth() <= 0.0F) {
            this.ejectPassengers();
            if (this.level().getGameRules().getBoolean(GameRules.RULE_DOENTITYDROPS)) {
                this.spawnAtLocation(ModItems.PITBIKE.get());
            }
            this.discard();
        }
        return true;
    }

    @Override
    public boolean causeFallDamage(float distance, float multiplier, DamageSource source) {
        return false;
    }

    @Override
    public boolean canBreatheUnderwater() {
        return true;
    }

    @Override
    public boolean canBeAffected(MobEffectInstance effect) {
        return false;
    }

    @Override
    public boolean canBeLeashed(Player player) {
        return false;
    }

    /** The bike itself is never targeted; its parts are. */
    @Override
    public boolean isPickable() {
        return false;
    }

    @Override
    public ItemStack getPickResult() {
        return new ItemStack(ModItems.PITBIKE.get());
    }

    @Override
    public boolean removeWhenFarAway(double distance) {
        return false;
    }

    @Override
    protected SoundEvent getHurtSound(DamageSource source) {
        return SoundEvents.ANVIL_HIT;
    }

    @Nullable
    @Override
    protected SoundEvent getDeathSound() {
        return null;
    }

    private record PartDef(String name, float damageMultiplier,
                           double minX, double minY, double minZ, double maxX, double maxY, double maxZ) {
    }
}
