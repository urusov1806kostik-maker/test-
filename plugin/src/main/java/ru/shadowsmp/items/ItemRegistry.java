package ru.shadowsmp.items;

import org.bukkit.Material;
import org.bukkit.NamespacedKey;
import org.bukkit.Registry;
import org.bukkit.attribute.Attribute;
import org.bukkit.attribute.AttributeModifier;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.enchantments.Enchantment;
import org.bukkit.inventory.EquipmentSlotGroup;
import org.bukkit.inventory.ItemFlag;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.persistence.PersistentDataType;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.EffectSpec;
import ru.shadowsmp.util.Keys;
import ru.shadowsmp.util.Text;

import java.io.File;
import java.util.*;

/** Загружает items.yml (оружие, инструменты, материалы, иконки) и talismans.yml. */
public class ItemRegistry {
    private final ShadowSMP plugin;
    private final Map<String, ItemDef> defs = new LinkedHashMap<>();

    public ItemRegistry(ShadowSMP plugin) {
        this.plugin = plugin;
        reload();
    }

    public void reload() {
        defs.clear();
        load("items.yml", "items", "custom:");
        load("talismans.yml", "talismans", "talisman:");
        plugin.getLogger().info("Загружено предметов/талисманов: " + defs.size());
    }

    private void load(String fileName, String root, String prefix) {
        File f = new File(plugin.getDataFolder(), fileName);
        YamlConfiguration y = YamlConfiguration.loadConfiguration(f);
        ConfigurationSection sec = y.getConfigurationSection(root);
        if (sec == null) return;
        for (String id : sec.getKeys(false)) {
            ConfigurationSection c = sec.getConfigurationSection(id);
            if (c == null) continue;
            try {
                defs.put(prefix + id, parse(prefix + id, c, prefix.equals("talisman:")));
            } catch (Exception ex) {
                plugin.getLogger().warning("Ошибка в " + fileName + " -> " + id + ": " + ex.getMessage());
            }
        }
    }

    private ItemDef parse(String fullId, ConfigurationSection c, boolean talisman) {
        Material mat = Material.matchMaterial(c.getString("material", talisman ? "TOTEM_OF_UNDYING" : "PAPER"));
        if (mat == null) throw new IllegalArgumentException("неизвестный material");
        Map<Enchantment, Integer> ench = new LinkedHashMap<>();
        ConfigurationSection es = c.getConfigurationSection("enchants");
        if (es != null) for (String k : es.getKeys(false)) {
            Enchantment e = Registry.ENCHANTMENT.get(NamespacedKey.minecraft(k.toLowerCase()));
            if (e != null) ench.put(e, es.getInt(k));
        }
        Map<String, Integer> cench = new LinkedHashMap<>();
        ConfigurationSection ces = c.getConfigurationSection("custom-enchants");
        if (ces != null) for (String k : ces.getKeys(false)) cench.put(k.toLowerCase(), ces.getInt(k));
        Map<Attribute, Double> attrs = new LinkedHashMap<>();
        ConfigurationSection as = c.getConfigurationSection("attributes");
        if (as != null) for (String k : as.getKeys(false)) {
            Attribute a = Registry.ATTRIBUTE.get(NamespacedKey.minecraft(k.toLowerCase()));
            if (a != null) attrs.put(a, as.getDouble(k));
        }
        return new ItemDef(fullId, mat, c.getString("name", fullId), c.getStringList("lore"),
                c.getString("model", null), c.getBoolean("glint", false), c.getBoolean("unbreakable", false),
                ench, cench, attrs, c.getString("slot", talisman ? "OFFHAND" : "MAINHAND").toUpperCase(),
                EffectSpec.parseList(c.getStringList("passive-effects")), CombatProfile.parse(c));
    }

    public Collection<ItemDef> all() {
        return defs.values();
    }

    public List<ItemDef> talismans() {
        return defs.values().stream().filter(ItemDef::isTalisman).toList();
    }

    public ItemDef def(String fullId) {
        return defs.get(fullId);
    }

    public ItemDef def(ItemStack it) {
        String id = idOf(it);
        return id == null ? null : defs.get(id);
    }

    public static String idOf(ItemStack it) {
        if (it == null || !it.hasItemMeta()) return null;
        return it.getItemMeta().getPersistentDataContainer().get(Keys.ITEM_ID, PersistentDataType.STRING);
    }

    public ItemStack create(String fullId) {
        ItemDef d = defs.get(fullId);
        return d == null ? null : create(d);
    }

    public ItemStack create(ItemDef d) {
        ItemStack it = new ItemStack(d.material());
        ItemMeta m = it.getItemMeta();
        m.setDisplayName(Text.color("&r" + d.name()));
        m.setLore(Text.color(d.lore()));
        if (d.model() != null && !d.model().isBlank()) m.setItemModel(NamespacedKey.fromString(d.model()));
        if (d.glint()) m.setEnchantmentGlintOverride(true);
        if (d.unbreakable()) { m.setUnbreakable(true); m.addItemFlags(ItemFlag.HIDE_UNBREAKABLE); }
        d.enchants().forEach((e, l) -> m.addEnchant(e, l, true));
        EquipmentSlotGroup group = slotGroup(d.slot());
        d.attributes().forEach((attr, val) -> m.addAttributeModifier(attr, new AttributeModifier(
                new NamespacedKey(plugin, "item_" + attr.getKey().getKey()), val, AttributeModifier.Operation.ADD_NUMBER, group)));
        if (d.isTalisman()) m.setMaxStackSize(1);
        m.getPersistentDataContainer().set(Keys.ITEM_ID, PersistentDataType.STRING, d.fullId());
        it.setItemMeta(m);
        d.customEnchants().forEach((id, lvl) -> plugin.enchants().apply(it, id, lvl));
        return it;
    }

    public static EquipmentSlotGroup slotGroup(String slot) {
        EquipmentSlotGroup g = EquipmentSlotGroup.getByName(slot.toLowerCase());
        return g == null ? EquipmentSlotGroup.MAINHAND : g;
    }

    /** custom:id, talisman:id, book:enchant:level или Material (DIAMOND). */
    public ItemStack resolve(String spec) {
        if (spec == null) return null;
        spec = spec.trim();
        if (spec.startsWith("custom:") || spec.startsWith("talisman:")) return create(spec);
        if (spec.startsWith("book:")) {
            String[] p = spec.split(":");
            return plugin.enchants().book(p[1], p.length > 2 ? Integer.parseInt(p[2]) : 1);
        }
        Material m = Material.matchMaterial(spec);
        return m == null || !m.isItem() ? null : new ItemStack(m);
    }

    public List<String> ids() {
        List<String> l = new ArrayList<>(defs.keySet());
        for (String e : plugin.enchants().ids()) l.add("book:" + e);
        return l;
    }
}
