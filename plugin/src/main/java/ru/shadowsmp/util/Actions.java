package ru.shadowsmp.util;

import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.NamespacedKey;
import org.bukkit.Registry;
import org.bukkit.Sound;
import org.bukkit.World;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;
import net.md_5.bungee.api.ChatMessageType;
import net.md_5.bungee.api.chat.TextComponent;
import ru.shadowsmp.ShadowSMP;

import java.util.List;

/**
 * Общий движок действий для кастом-команд и NPC.
 * [player] cmd | [console] cmd | [message] txt | [broadcast] txt | [title] t;sub | [actionbar] txt
 * [sound] SOUND:vol:pitch | [delay] тики | [coins] n | [shadowcoins] n | [give] id*кол | [effect] SPEC
 * [spawn] | [teleport] world;x;y;z | [close] | [menu] shop|crafts
 */
public final class Actions {
    private Actions() {}

    public static void run(Player p, List<String> actions, String[] args) {
        runFrom(p, actions, args, 0);
    }

    private static void runFrom(Player p, List<String> actions, String[] args, int start) {
        ShadowSMP plugin = ShadowSMP.get();
        for (int i = start; i < actions.size(); i++) {
            String raw = actions.get(i).trim();
            String type = "[console]";
            String value = raw;
            if (raw.startsWith("[")) {
                int end = raw.indexOf(']');
                type = raw.substring(0, end + 1).toLowerCase();
                value = raw.substring(end + 1).trim();
            }
            value = placeholders(p, value, args);
            if (type.equals("[delay]")) {
                final int next = i + 1;
                long ticks = parseLong(value, 20);
                Bukkit.getScheduler().runTaskLater(plugin, () -> {
                    if (p.isOnline()) runFrom(p, actions, args, next);
                }, ticks);
                return;
            }
            execute(plugin, p, type, value);
        }
    }

    private static void execute(ShadowSMP plugin, Player p, String type, String value) {
        switch (type) {
            case "[player]" -> p.performCommand(value.startsWith("/") ? value.substring(1) : value);
            case "[console]" -> Bukkit.dispatchCommand(Bukkit.getConsoleSender(), value.startsWith("/") ? value.substring(1) : value);
            case "[message]" -> p.sendMessage(Text.color(value));
            case "[broadcast]" -> Bukkit.broadcastMessage(Text.color(value));
            case "[title]" -> {
                String[] t = value.split(";", 2);
                p.sendTitle(Text.color(t[0]), t.length > 1 ? Text.color(t[1]) : "", 10, 50, 15);
            }
            case "[actionbar]" -> p.spigot().sendMessage(ChatMessageType.ACTION_BAR, TextComponent.fromLegacy(Text.color(value)));
            case "[sound]" -> {
                String[] s = value.split(":");
                Sound sound = soundByName(s[0]);
                if (sound != null) p.playSound(p.getLocation(), sound,
                        s.length > 1 ? Float.parseFloat(s[1]) : 1f, s.length > 2 ? Float.parseFloat(s[2]) : 1f);
            }
            case "[coins]" -> plugin.economy().add(p.getUniqueId(), false, Double.parseDouble(value));
            case "[shadowcoins]" -> plugin.economy().add(p.getUniqueId(), true, Double.parseDouble(value));
            case "[give]" -> {
                String[] g = value.split("\\*");
                ItemStack it = plugin.items().resolve(g[0].trim());
                if (it != null) {
                    it.setAmount(g.length > 1 ? Integer.parseInt(g[1].trim()) : 1);
                    p.getInventory().addItem(it).values().forEach(left -> p.getWorld().dropItem(p.getLocation(), left));
                }
            }
            case "[effect]" -> {
                EffectSpec e = EffectSpec.parse(value);
                if (e != null) e.apply(p);
            }
            case "[spawn]" -> plugin.spawn().teleport(p);
            case "[teleport]" -> {
                String[] t = value.split(";");
                World w = Bukkit.getWorld(t[0]);
                if (w != null && t.length >= 4)
                    p.teleport(new Location(w, Double.parseDouble(t[1]), Double.parseDouble(t[2]), Double.parseDouble(t[3])));
            }
            case "[close]" -> p.closeInventory();
            case "[menu]" -> {
                if (value.equalsIgnoreCase("crafts")) plugin.crafts().openViewer(p, 0);
                else plugin.shop().open(p);
            }
            default -> plugin.getLogger().warning("Неизвестное действие: " + type);
        }
    }

    /** Принимает и ENTITY_PLAYER_LEVELUP, и entity.player.levelup. */
    @SuppressWarnings("deprecation")
    public static Sound soundByName(String name) {
        if (name.contains(".")) return Registry.SOUNDS.get(NamespacedKey.minecraft(name.toLowerCase()));
        try {
            return Sound.valueOf(name.toUpperCase());
        } catch (Exception e) {
            return null;
        }
    }

    public static String placeholders(Player p, String s, String[] args) {
        s = s.replace("{player}", p.getName())
                .replace("{world}", p.getWorld().getName())
                .replace("{args}", args == null ? "" : String.join(" ", args));
        if (args != null) for (int i = 0; i < args.length; i++) s = s.replace("{arg" + (i + 1) + "}", args[i]);
        return s;
    }

    private static long parseLong(String s, long def) {
        try { return Long.parseLong(s.trim()); } catch (Exception e) { return def; }
    }
}
