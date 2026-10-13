package ru.shadowsmp.economy;

import org.bukkit.Bukkit;
import org.bukkit.OfflinePlayer;
import org.bukkit.configuration.file.YamlConfiguration;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Text;

import java.io.File;
import java.io.IOException;
import java.util.*;

/** Две валюты: Монеты (обычная) и ShadowCoin (донатная). */
public class Economy {
    private final ShadowSMP plugin;
    private final File file;
    private final Map<UUID, double[]> balances = new HashMap<>();
    private boolean dirty;

    public Economy(ShadowSMP plugin) {
        this.plugin = plugin;
        this.file = new File(plugin.getDataFolder(), "data/economy.yml");
        load();
        Bukkit.getScheduler().runTaskTimerAsynchronously(plugin, () -> { if (dirty) save(); }, 1200, 1200);
    }

    private void load() {
        YamlConfiguration y = YamlConfiguration.loadConfiguration(file);
        for (String k : y.getKeys(false)) {
            try {
                balances.put(UUID.fromString(k), new double[]{y.getDouble(k + ".coins"), y.getDouble(k + ".shadowcoins")});
            } catch (IllegalArgumentException ignored) {}
        }
    }

    public synchronized void save() {
        YamlConfiguration y = new YamlConfiguration();
        for (Map.Entry<UUID, double[]> e : balances.entrySet()) {
            OfflinePlayer op = Bukkit.getOfflinePlayer(e.getKey());
            y.set(e.getKey() + ".name", op.getName());
            y.set(e.getKey() + ".coins", e.getValue()[0]);
            y.set(e.getKey() + ".shadowcoins", e.getValue()[1]);
        }
        try {
            file.getParentFile().mkdirs();
            y.save(file);
            dirty = false;
        } catch (IOException ex) {
            plugin.getLogger().warning("Не удалось сохранить экономику: " + ex.getMessage());
        }
    }

    private synchronized double[] acc(UUID id) {
        return balances.computeIfAbsent(id, k -> new double[]{plugin.getConfig().getDouble("economy.start-coins", 100), 0});
    }

    public synchronized double get(UUID id, boolean shadow) {
        return acc(id)[shadow ? 1 : 0];
    }

    public synchronized void set(UUID id, boolean shadow, double v) {
        acc(id)[shadow ? 1 : 0] = Math.max(0, v);
        dirty = true;
    }

    public synchronized void add(UUID id, boolean shadow, double v) {
        set(id, shadow, get(id, shadow) + v);
    }

    public synchronized boolean take(UUID id, boolean shadow, double v) {
        if (get(id, shadow) < v) return false;
        set(id, shadow, get(id, shadow) - v);
        return true;
    }

    public void ensure(UUID id) {
        acc(id);
        dirty = true;
    }

    public synchronized List<Map.Entry<UUID, Double>> top(boolean shadow, int limit) {
        List<Map.Entry<UUID, Double>> list = new ArrayList<>();
        for (Map.Entry<UUID, double[]> e : balances.entrySet())
            list.add(Map.entry(e.getKey(), e.getValue()[shadow ? 1 : 0]));
        list.sort((a, b) -> Double.compare(b.getValue(), a.getValue()));
        return list.subList(0, Math.min(limit, list.size()));
    }

    public String name(boolean shadow) {
        return Text.color(shadow ? plugin.getConfig().getString("economy.shadow-name", "&5ShadowCoin")
                : plugin.getConfig().getString("economy.coins-name", "&6Монеты"));
    }

    public String format(double v, boolean shadow) {
        return Text.color((shadow ? "&d" : "&e") + Text.formatNumber(v) + " " + name(shadow));
    }

    /** "coins"/"монеты" -> false, "shadow"/"shadowcoin"/"sc" -> true */
    public static Boolean parseCurrency(String s) {
        s = s.toLowerCase();
        if (s.startsWith("coin") || s.startsWith("мон") || s.equals("c")) return false;
        if (s.startsWith("shadow") || s.equals("sc") || s.startsWith("шад")) return true;
        return null;
    }
}
