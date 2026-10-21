package com.pitbike.client;

import com.pitbike.ModSounds;
import com.pitbike.entity.PitbikeEntity;
import net.minecraft.client.resources.sounds.AbstractTickableSoundInstance;
import net.minecraft.client.resources.sounds.SoundInstance;
import net.minecraft.sounds.SoundSource;
import net.minecraft.util.Mth;

/** Engine loop that follows the bike; pitch and volume rise with speed. Stops when the rider gets off. */
public class EngineSound extends AbstractTickableSoundInstance {
    private final PitbikeEntity bike;

    public EngineSound(PitbikeEntity bike) {
        super(ModSounds.ENGINE.get(), SoundSource.NEUTRAL, SoundInstance.createUnseededRandom());
        this.bike = bike;
        this.looping = true;
        this.delay = 0;
        this.volume = 0.5F;
        this.pitch = 0.6F;
        this.x = bike.getX();
        this.y = bike.getY();
        this.z = bike.getZ();
    }

    @Override
    public void tick() {
        if (this.bike.isRemoved() || !this.bike.isVehicle()) {
            this.stop();
            return;
        }
        this.x = this.bike.getX();
        this.y = this.bike.getY();
        this.z = this.bike.getZ();
        float speed = Math.abs(this.bike.getDrivingSpeed());
        this.pitch = Mth.lerp(0.3F, this.pitch, Mth.clamp(0.6F + speed * 1.6F, 0.6F, 1.8F));
        this.volume = Mth.lerp(0.3F, this.volume, Mth.clamp(0.5F + speed * 0.7F, 0.5F, 1.0F));
    }

    @Override
    public boolean canStartSilent() {
        return true;
    }
}
