package ru.shadowsmp.enchants;

import org.bukkit.Material;

/** Кастомное зачарование: id, название, макс. уровень, к чему применимо. */
public record CustomEnchant(String id, String name, int maxLevel, Target target, String description) {

    public enum Target {
        WEAPON, TOOL, PICKAXE, ARMOR, HELMET, BOOTS, ANY;

        public boolean fits(Material m) {
            String n = m.name();
            boolean weapon = n.endsWith("_SWORD") || n.endsWith("_AXE") || n.equals("MACE") || n.equals("TRIDENT") || n.endsWith("_SPEAR");
            boolean tool = n.endsWith("_PICKAXE") || n.endsWith("_SHOVEL") || n.endsWith("_AXE") || n.endsWith("_HOE");
            return switch (this) {
                case WEAPON -> weapon;
                case TOOL -> tool;
                case PICKAXE -> n.endsWith("_PICKAXE");
                case ARMOR -> n.endsWith("_HELMET") || n.endsWith("_CHESTPLATE") || n.endsWith("_LEGGINGS") || n.endsWith("_BOOTS");
                case HELMET -> n.endsWith("_HELMET");
                case BOOTS -> n.endsWith("_BOOTS");
                case ANY -> true;
            };
        }

        public String ru() {
            return switch (this) {
                case WEAPON -> "Оружие";
                case TOOL -> "Инструменты";
                case PICKAXE -> "Кирки";
                case ARMOR -> "Броня";
                case HELMET -> "Шлемы";
                case BOOTS -> "Ботинки";
                case ANY -> "Всё";
            };
        }
    }
}
