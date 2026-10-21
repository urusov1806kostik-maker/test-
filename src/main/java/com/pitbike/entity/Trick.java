package com.pitbike.entity;

import net.minecraft.network.chat.Component;
import org.jetbrains.annotations.Nullable;

/** Air tricks. Landing before a trick is finished throws the rider off. */
public enum Trick {
    ONE_HANDER("one_hander", 10, 100),
    NO_HANDER("no_hander", 12, 150),
    SUPERMAN("superman", 16, 250),
    BACKFLIP("backflip", 20, 400),
    SPIN("spin", 16, 300);

    public final String id;
    public final int duration;
    public final int points;

    Trick(String id, int duration, int points) {
        this.id = id;
        this.duration = duration;
        this.points = points;
    }

    /** Network id: 1-based so 0 can mean "no trick". */
    public int networkId() {
        return this.ordinal() + 1;
    }

    @Nullable
    public static Trick byNetworkId(int id) {
        return id >= 1 && id <= values().length ? values()[id - 1] : null;
    }

    public Component displayName() {
        return Component.translatable("trick.pitbike." + this.id);
    }
}
