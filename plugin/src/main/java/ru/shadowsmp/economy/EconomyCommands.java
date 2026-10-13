package ru.shadowsmp.economy;

import org.bukkit.Bukkit;
import org.bukkit.OfflinePlayer;
import org.bukkit.command.*;
import org.bukkit.entity.Player;
import org.bukkit.entity.Monster;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntityDeathEvent;
import org.bukkit.event.player.PlayerJoinEvent;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Msg;
import ru.shadowsmp.util.Text;

import java.util.*;

/** /money, /mpay, /mtop, /seco */
public class EconomyCommands implements CommandExecutor, TabCompleter, Listener {
    private final ShadowSMP plugin;

    public EconomyCommands(ShadowSMP plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender s, Command cmd, String label, String[] a) {
        Economy eco = plugin.economy();
        switch (cmd.getName().toLowerCase()) {
            case "money" -> {
                OfflinePlayer target = a.length > 0 && s.hasPermission("shadowsmp.money.others") ? Bukkit.getOfflinePlayer(a[0])
                        : s instanceof Player p ? p : null;
                if (target == null) { Msg.send(s, "&cИспользование: /money <игрок>"); return true; }
                s.sendMessage(Text.color("&8&m                                        "));
                s.sendMessage(Text.color("  &7Баланс &f" + target.getName()));
                s.sendMessage(Text.color("  &6⛃ " + eco.format(eco.get(target.getUniqueId(), false), false)));
                s.sendMessage(Text.color("  &5✦ " + eco.format(eco.get(target.getUniqueId(), true), true)));
                s.sendMessage(Text.color("&8&m                                        "));
            }
            case "mpay" -> {
                if (!(s instanceof Player p)) return true;
                if (a.length < 2) { Msg.send(s, "&cИспользование: /mpay <игрок> <сумма> [coins|shadow]"); return true; }
                Player to = Bukkit.getPlayerExact(a[0]);
                if (to == null || to == p) { Msg.send(s, "&cИгрок не найден."); return true; }
                double amount;
                try { amount = Double.parseDouble(a[1]); } catch (NumberFormatException e) { Msg.send(s, "&cНеверная сумма."); return true; }
                if (amount <= 0 || Double.isNaN(amount) || Double.isInfinite(amount)) { Msg.send(s, "&cНеверная сумма."); return true; }
                boolean shadow = a.length > 2 && Boolean.TRUE.equals(Economy.parseCurrency(a[2]));
                if (shadow && !plugin.getConfig().getBoolean("economy.allow-shadow-pay", true)) {
                    Msg.send(s, "&cПередавать ShadowCoin нельзя."); return true;
                }
                if (!eco.take(p.getUniqueId(), shadow, amount)) { Msg.send(s, "&cНедостаточно средств."); return true; }
                eco.add(to.getUniqueId(), shadow, amount);
                Msg.send(p, "&aВы перевели " + eco.format(amount, shadow) + " &aигроку &f" + to.getName());
                Msg.send(to, "&aВы получили " + eco.format(amount, shadow) + " &aот &f" + p.getName());
            }
            case "mtop" -> {
                boolean shadow = a.length > 0 && Boolean.TRUE.equals(Economy.parseCurrency(a[0]));
                s.sendMessage(Text.color("&8&m          &r &5&lТОП " + Text.strip(eco.name(shadow)) + " &8&m          "));
                int i = 1;
                for (Map.Entry<UUID, Double> e : eco.top(shadow, 10)) {
                    String n = Bukkit.getOfflinePlayer(e.getKey()).getName();
                    s.sendMessage(Text.color(" &d" + i++ + ". &f" + n + " &8— " + eco.format(e.getValue(), shadow)));
                }
            }
            case "seco" -> {
                if (a.length < 4) { Msg.send(s, "&cИспользование: /seco <give|take|set> <игрок> <coins|shadow> <сумма>"); return true; }
                OfflinePlayer t = Bukkit.getOfflinePlayer(a[1]);
                Boolean shadow = Economy.parseCurrency(a[2]);
                if (shadow == null) { Msg.send(s, "&cВалюта: coins или shadow"); return true; }
                double v;
                try { v = Double.parseDouble(a[3]); } catch (NumberFormatException e) { Msg.send(s, "&cНеверная сумма."); return true; }
                switch (a[0].toLowerCase()) {
                    case "give" -> eco.add(t.getUniqueId(), shadow, v);
                    case "take" -> eco.set(t.getUniqueId(), shadow, eco.get(t.getUniqueId(), shadow) - v);
                    case "set" -> eco.set(t.getUniqueId(), shadow, v);
                    default -> { Msg.send(s, "&cgive/take/set"); return true; }
                }
                Msg.send(s, "&aГотово. Баланс " + t.getName() + ": " + eco.format(eco.get(t.getUniqueId(), shadow), shadow));
            }
        }
        return true;
    }

    @Override
    public List<String> onTabComplete(CommandSender s, Command cmd, String label, String[] a) {
        String n = cmd.getName().toLowerCase();
        if (n.equals("seco")) {
            if (a.length == 1) return filter(List.of("give", "take", "set"), a[0]);
            if (a.length == 2) return null;
            if (a.length == 3) return filter(List.of("coins", "shadow"), a[2]);
        }
        if (n.equals("mpay")) {
            if (a.length == 1) return null;
            if (a.length == 3) return filter(List.of("coins", "shadow"), a[2]);
        }
        if (n.equals("mtop") && a.length == 1) return filter(List.of("coins", "shadow"), a[0]);
        if (n.equals("money") && a.length == 1) return null;
        return List.of();
    }

    static List<String> filter(List<String> l, String p) {
        return l.stream().filter(x -> x.toLowerCase().startsWith(p.toLowerCase())).toList();
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        plugin.economy().ensure(e.getPlayer().getUniqueId());
    }

    @EventHandler
    public void onKill(EntityDeathEvent e) {
        Player killer = e.getEntity().getKiller();
        if (killer == null) return;
        double reward;
        if (e.getEntity() instanceof Player) reward = plugin.getConfig().getDouble("economy.reward.player-kill", 25);
        else if (e.getEntity() instanceof Monster) reward = plugin.getConfig().getDouble("economy.reward.monster-kill", 2);
        else reward = plugin.getConfig().getDouble("economy.reward.animal-kill", 0.5);
        if (reward > 0) {
            plugin.economy().add(killer.getUniqueId(), false, reward);
            plugin.board().actionBar(killer, "&6+" + Text.formatNumber(reward) + " " + Text.strip(plugin.economy().name(false)));
        }
    }
}
