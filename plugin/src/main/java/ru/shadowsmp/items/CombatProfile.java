package ru.shadowsmp.items;

import org.bukkit.configuration.ConfigurationSection;
import ru.shadowsmp.util.EffectSpec;

import java.util.List;

/** Что происходит при ударе (on-hit) и при получении урона (on-damaged). */
public record CombatProfile(
        List<EffectSpec> hitTarget, List<EffectSpec> hitSelf, int hitFire, double lightningChance,
        double lifesteal, double bonusDamage,
        List<EffectSpec> hurtAttacker, List<EffectSpec> hurtSelf, int hurtFire, double dodgeChance, double thorns) {

    public static final CombatProfile EMPTY = new CombatProfile(List.of(), List.of(), 0, 0, 0, 0, List.of(), List.of(), 0, 0, 0);

    public static CombatProfile parse(ConfigurationSection sec) {
        if (sec == null) return EMPTY;
        ConfigurationSection hit = sec.getConfigurationSection("on-hit");
        ConfigurationSection hurt = sec.getConfigurationSection("on-damaged");
        return new CombatProfile(
                hit == null ? List.of() : EffectSpec.parseList(hit.getStringList("target")),
                hit == null ? List.of() : EffectSpec.parseList(hit.getStringList("self")),
                hit == null ? 0 : hit.getInt("fire"),
                hit == null ? 0 : hit.getDouble("lightning-chance"),
                hit == null ? 0 : hit.getDouble("lifesteal"),
                hit == null ? 0 : hit.getDouble("bonus-damage"),
                hurt == null ? List.of() : EffectSpec.parseList(hurt.getStringList("attacker")),
                hurt == null ? List.of() : EffectSpec.parseList(hurt.getStringList("self")),
                hurt == null ? 0 : hurt.getInt("fire"),
                hurt == null ? 0 : hurt.getDouble("dodge-chance"),
                hurt == null ? 0 : hurt.getDouble("thorns"));
    }
}
