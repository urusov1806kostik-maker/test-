package ru.shadowsmp.util;

import org.bukkit.NamespacedKey;
import ru.shadowsmp.ShadowSMP;

public final class Keys {
    public static NamespacedKey ITEM_ID, ENCH_LINES, NPC_ID, HOLOGRAM, BOSS, TREASURE, SPAWN_DECOR;

    private Keys() {}

    public static void init(ShadowSMP plugin) {
        ITEM_ID = new NamespacedKey(plugin, "item_id");
        ENCH_LINES = new NamespacedKey(plugin, "ench_lines");
        NPC_ID = new NamespacedKey(plugin, "npc_id");
        HOLOGRAM = new NamespacedKey(plugin, "hologram");
        BOSS = new NamespacedKey(plugin, "event_boss");
        TREASURE = new NamespacedKey(plugin, "treasure");
        SPAWN_DECOR = new NamespacedKey(plugin, "spawn_decor");
    }

    public static NamespacedKey of(String key) {
        return new NamespacedKey(ShadowSMP.get(), key);
    }
}
