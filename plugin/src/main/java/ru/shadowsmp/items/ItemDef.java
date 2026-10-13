package ru.shadowsmp.items;

import org.bukkit.Material;
import org.bukkit.attribute.Attribute;
import org.bukkit.enchantments.Enchantment;
import ru.shadowsmp.util.EffectSpec;

import java.util.List;
import java.util.Map;

/** Описание кастом-предмета или талисмана. */
public record ItemDef(
        String fullId, Material material, String name, List<String> lore, String model, boolean glint,
        boolean unbreakable, Map<Enchantment, Integer> enchants, Map<String, Integer> customEnchants,
        Map<Attribute, Double> attributes, String slot, List<EffectSpec> passive, CombatProfile combat) {

    public boolean isTalisman() {
        return fullId.startsWith("talisman:");
    }

    public String shortId() {
        return fullId.substring(fullId.indexOf(':') + 1);
    }
}
