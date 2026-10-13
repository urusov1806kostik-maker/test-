package ru.shadowsmp.shop;

import org.bukkit.Bukkit;
import org.bukkit.Material;
import org.bukkit.Sound;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.inventory.InventoryDragEvent;
import org.bukkit.inventory.Inventory;
import org.bukkit.inventory.InventoryHolder;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.meta.ItemMeta;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Msg;
import ru.shadowsmp.util.Text;

import java.io.File;
import java.util.*;

/** Магазин за Монеты и ShadowCoin (shop.yml). */
public class Shop implements Listener {
    private final ShadowSMP plugin;
    private final List<Entry> entries = new ArrayList<>();

    record Entry(int slot, String item, int amount, double price, boolean shadow, String command, String name, List<String> lore) {}

    static class Holder implements InventoryHolder {
        Inventory inv;
        @Override public Inventory getInventory() { return inv; }
    }

    public Shop(ShadowSMP plugin) {
        this.plugin = plugin;
        reload();
    }

    public void reload() {
        entries.clear();
        YamlConfiguration y = YamlConfiguration.loadConfiguration(new File(plugin.getDataFolder(), "shop.yml"));
        ConfigurationSection sec = y.getConfigurationSection("items");
        if (sec != null) for (String k : sec.getKeys(false)) {
            ConfigurationSection c = sec.getConfigurationSection(k);
            entries.add(new Entry(c.getInt("slot"), c.getString("item"), c.getInt("amount", 1), c.getDouble("price"),
                    c.getString("currency", "coins").toLowerCase().startsWith("shadow"), c.getString("command", ""),
                    c.getString("name", null), c.getStringList("lore")));
        }
    }

    public void open(Player p) {
        Holder h = new Holder();
        Inventory inv = Bukkit.createInventory(h, 54, Text.color("&5&lМагазин ShadowSMP"));
        h.inv = inv;
        ItemStack pane = new ItemStack(Material.BLACK_STAINED_GLASS_PANE);
        ItemMeta pm = pane.getItemMeta();
        pm.setDisplayName(" ");
        pane.setItemMeta(pm);
        for (int i = 45; i < 54; i++) inv.setItem(i, pane);
        inv.setItem(48, icon("custom:coin_icon", Material.GOLD_NUGGET, "&6Монеты: &f" + Text.formatNumber(plugin.economy().get(p.getUniqueId(), false))));
        inv.setItem(50, icon("custom:shadowcoin_icon", Material.AMETHYST_SHARD, "&5ShadowCoin: &f" + Text.formatNumber(plugin.economy().get(p.getUniqueId(), true))));
        for (Entry e : entries) {
            ItemStack it = plugin.items().resolve(e.item());
            if (it == null) continue;
            it.setAmount(Math.max(1, Math.min(64, e.amount())));
            ItemMeta m = it.getItemMeta();
            if (e.name() != null) m.setDisplayName(Text.color(e.name()));
            List<String> lore = m.hasLore() ? new ArrayList<>(m.getLore()) : new ArrayList<>();
            lore.addAll(Text.color(e.lore()));
            lore.add("");
            lore.add(Text.color("&7Цена: " + plugin.economy().format(e.price(), e.shadow())));
            lore.add(Text.color("&eНажми, чтобы купить"));
            m.setLore(lore);
            it.setItemMeta(m);
            inv.setItem(e.slot(), it);
        }
        p.openInventory(inv);
    }

    private ItemStack icon(String id, Material fallback, String name) {
        ItemStack it = plugin.items().resolve(id);
        if (it == null) it = new ItemStack(fallback);
        ItemMeta m = it.getItemMeta();
        m.setDisplayName(Text.color(name));
        m.setLore(List.of());
        it.setItemMeta(m);
        return it;
    }

    @EventHandler
    public void onClick(InventoryClickEvent e) {
        if (!(e.getInventory().getHolder() instanceof Holder)) return;
        e.setCancelled(true);
        if (!(e.getWhoClicked() instanceof Player p) || e.getClickedInventory() != e.getInventory()) return;
        for (Entry en : entries) {
            if (en.slot() != e.getSlot()) continue;
            if (!plugin.economy().take(p.getUniqueId(), en.shadow(), en.price())) {
                Msg.send(p, "&cНедостаточно средств! Нужно " + plugin.economy().format(en.price(), en.shadow()));
                p.playSound(p.getLocation(), Sound.ENTITY_VILLAGER_NO, 1, 1);
                return;
            }
            if (!en.command().isBlank()) Bukkit.dispatchCommand(Bukkit.getConsoleSender(), en.command().replace("{player}", p.getName()));
            else {
                ItemStack it = plugin.items().resolve(en.item());
                it.setAmount(en.amount());
                p.getInventory().addItem(it).values().forEach(l -> p.getWorld().dropItem(p.getLocation(), l));
            }
            p.playSound(p.getLocation(), Sound.ENTITY_EXPERIENCE_ORB_PICKUP, 1, 1.3f);
            Msg.send(p, "&aПокупка успешна!");
            open(p);
            return;
        }
    }

    @EventHandler
    public void onDrag(InventoryDragEvent e) {
        if (e.getInventory().getHolder() instanceof Holder) e.setCancelled(true);
    }
}
