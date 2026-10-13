package ru.shadowsmp.util;

import org.bukkit.NamespacedKey;
import org.bukkit.Registry;
import org.bukkit.entity.LivingEntity;
import org.bukkit.potion.PotionEffect;
import org.bukkit.potion.PotionEffectType;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ThreadLocalRandom;

/** Формат: "ЭФФЕКТ:уровень:длительность_в_тиках:шанс%", например "POISON:2:100:30". */
public record EffectSpec(PotionEffectType type, int amplifier, int duration, double chance) {

    public static EffectSpec parse(String raw) {
        if (raw == null || raw.isBlank()) return null;
        String[] p = raw.trim().split(":");
        PotionEffectType type = effectType(p[0]);
        if (type == null) return null;
        int level = p.length > 1 ? Integer.parseInt(p[1].trim()) : 1;
        int duration = p.length > 2 ? Integer.parseInt(p[2].trim()) : 100;
        double chance = p.length > 3 ? Double.parseDouble(p[3].trim()) : 100;
        return new EffectSpec(type, Math.max(0, level - 1), duration, chance);
    }

    public static List<EffectSpec> parseList(List<String> raw) {
        List<EffectSpec> out = new ArrayList<>();
        if (raw != null) for (String s : raw) {
            try {
                EffectSpec e = parse(s);
                if (e != null) out.add(e);
            } catch (Exception ignored) {}
        }
        return out;
    }

    public static PotionEffectType effectType(String name) {
        return Registry.EFFECT.get(NamespacedKey.minecraft(name.trim().toLowerCase()));
    }

    public boolean roll() {
        return chance >= 100 || ThreadLocalRandom.current().nextDouble(100) < chance;
    }

    public void apply(LivingEntity e) {
        if (e != null && roll()) e.addPotionEffect(new PotionEffect(type, duration, amplifier, false, true, true));
    }
}
