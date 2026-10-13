package ru.shadowsmp.commands;

import org.bukkit.Bukkit;
import org.bukkit.command.*;
import org.bukkit.entity.Player;
import org.bukkit.inventory.ItemStack;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.enchants.CustomEnchant;
import ru.shadowsmp.enchants.EnchantManager;
import ru.shadowsmp.items.ItemDef;
import ru.shadowsmp.util.Msg;
import ru.shadowsmp.util.Text;

import java.util.*;

/** /shadowsmp, /spawn, /setspawn, /talisman, /citem, /cenchant, /crafts, /shop, /sb, /buildspawn */
public class MainCommands implements CommandExecutor, TabCompleter {
    private final ShadowSMP plugin;

    public MainCommands(ShadowSMP plugin) {
        this.plugin = plugin;
    }

    @Override
    public boolean onCommand(CommandSender s, Command cmd, String label, String[] a) {
        Player p = s instanceof Player pl ? pl : null;
        switch (cmd.getName().toLowerCase()) {
            case "shadowsmp" -> {
                if (a.length > 0 && a[0].equalsIgnoreCase("reload") && s.hasPermission("shadowsmp.admin")) {
                    plugin.reloadAll();
                    Msg.send(s, "&aВсе модули ShadowSMP перезагружены.");
                    return true;
                }
                for (String l : List.of("<g:#7B2FF7:#F107A3>&l✦ ShadowSMP ✦</g> &7v" + plugin.getDescription().getVersion(),
                        "&f/spawn &8— &7на спавн", "&f/money, /mpay, /mtop &8— &7экономика", "&f/shop &8— &7магазин",
                        "&f/crafts &8— &7кастом крафты", "&f/talisman list &8— &7талисманы", "&f/event &8— &7ивенты",
                        "&f/sb &8— &7скрыть/показать скорборд", "&f/changepassword &8— &7сменить пароль",
                        "&8Админ: /shadowsmp reload, /citem, /cenchant, /talisman give, /npc, /ccmd, /seco, /event start, /buildspawn"))
                    s.sendMessage(Text.color(l));
            }
            case "spawn" -> {
                Player t = a.length > 0 && s.hasPermission("shadowsmp.spawn.others") ? Bukkit.getPlayerExact(a[0]) : p;
                if (t == null) return true;
                int delay = s.hasPermission("shadowsmp.spawn.instant") ? 0 : plugin.getConfig().getInt("spawn.teleport-delay", 3);
                if (delay <= 0) plugin.spawn().teleport(t);
                else {
                    Msg.send(t, "&7Телепорт на спавн через &f" + delay + " сек&7, не двигайтесь...");
                    var start = t.getLocation().clone();
                    Bukkit.getScheduler().runTaskLater(plugin, () -> {
                        if (!t.isOnline()) return;
                        if (t.getLocation().distanceSquared(start) > 1) { Msg.send(t, "&cТелепорт отменён — вы сдвинулись."); return; }
                        plugin.spawn().teleport(t);
                    }, delay * 20L);
                }
            }
            case "setspawn" -> {
                if (p == null) return true;
                plugin.spawn().set(p.getLocation());
                Msg.send(s, "&aСпавн установлен.");
            }
            case "buildspawn" -> {
                if (p == null && a.length >= 5) { // из консоли: /buildspawn confirm <мир> <x> <y> <z>
                    var w = Bukkit.getWorld(a[1]);
                    if (w == null) { Msg.send(s, "&cМир не найден."); return true; }
                    plugin.spawn().build(s, new org.bukkit.Location(w, Double.parseDouble(a[2]), Double.parseDouble(a[3]), Double.parseDouble(a[4])));
                    return true;
                }
                if (p == null) { Msg.send(s, "&c/buildspawn confirm <мир> <x> <y> <z>"); return true; }
                if (a.length == 0 || !a[0].equalsIgnoreCase("confirm")) {
                    Msg.send(s, "&eПостроит спавн радиусом ~22 блока вокруг вас (блоки будут заменены).");
                    Msg.send(s, "&eПодтвердите: &f/buildspawn confirm");
                    return true;
                }
                plugin.spawn().build(p, p.getLocation());
            }
            case "shop" -> { if (p != null) plugin.shop().open(p); }
            case "crafts" -> { if (p != null) plugin.crafts().openViewer(p, 0); }
            case "sb" -> { if (p != null) plugin.board().toggle(p); }
            case "talisman" -> talisman(s, a);
            case "citem" -> citem(s, a);
            case "cenchant" -> cenchant(s, a);
        }
        return true;
    }

    private void give(CommandSender s, String target, String id, int amount) {
        Player t = Bukkit.getPlayerExact(target);
        if (t == null) { Msg.send(s, "&cИгрок не найден."); return; }
        ItemStack it = plugin.items().resolve(id);
        if (it == null) { Msg.send(s, "&cПредмет " + id + " не найден."); return; }
        it.setAmount(Math.max(1, amount));
        t.getInventory().addItem(it).values().forEach(l -> t.getWorld().dropItem(t.getLocation(), l));
        Msg.send(s, "&aВыдано: " + it.getItemMeta().getDisplayName() + " &ax" + amount + " &7→ &f" + t.getName());
    }

    private void talisman(CommandSender s, String[] a) {
        if (a.length == 0 || a[0].equalsIgnoreCase("list")) {
            s.sendMessage(Text.color("&5&lТалисманы &7(работают в левой руке):"));
            for (ItemDef d : plugin.items().talismans()) {
                s.sendMessage(Text.color(" &8• &r" + d.name() + " &8(" + d.shortId() + ")"));
                if (!d.lore().isEmpty()) s.sendMessage(Text.color("   " + d.lore().get(0)));
            }
            s.sendMessage(Text.color("&7Крафты: &f/crafts"));
            return;
        }
        if (!s.hasPermission("shadowsmp.admin")) { Msg.send(s, "&cНет прав."); return; }
        if (a[0].equalsIgnoreCase("give") && a.length >= 3) give(s, a[1], "talisman:" + a[2], 1);
        else Msg.send(s, "&c/talisman give <игрок> <id>");
    }

    private void citem(CommandSender s, String[] a) {
        if (a.length == 0 || a[0].equalsIgnoreCase("list")) {
            Msg.send(s, "&7Предметы: &f" + String.join(", ", plugin.items().ids()));
            return;
        }
        if (a[0].equalsIgnoreCase("give") && a.length >= 3) give(s, a[1], a[2], a.length > 3 ? Integer.parseInt(a[3]) : 1);
        else Msg.send(s, "&c/citem give <игрок> <id> [кол-во] &7| &c/citem list");
    }

    private void cenchant(CommandSender s, String[] a) {
        if (a.length == 0 || a[0].equalsIgnoreCase("list")) {
            s.sendMessage(Text.color("&5&lКастом зачарования:"));
            for (CustomEnchant ce : plugin.enchants().all())
                s.sendMessage(Text.color(" &8• &r" + ce.name() + " &8(" + ce.id() + ", макс " + ce.maxLevel() + ", " + ce.target().ru() + ") &7" + ce.description()));
            return;
        }
        if (a[0].equalsIgnoreCase("book") && a.length >= 3) {
            give(s, a[1], "book:" + a[2] + ":" + (a.length > 3 ? a[3] : "1"), 1);
            return;
        }
        if (a[0].equalsIgnoreCase("apply") && a.length >= 2 && s instanceof Player p) {
            CustomEnchant ce = plugin.enchants().get(a[1]);
            ItemStack hand = p.getInventory().getItemInMainHand();
            if (ce == null || hand.getType().isAir()) { Msg.send(s, "&cВозьмите предмет в руку и укажите зачарование."); return; }
            int lvl = a.length > 2 ? Integer.parseInt(a[2]) : 1;
            plugin.enchants().apply(hand, ce.id(), lvl);
            Msg.send(s, "&aНаложено: " + ce.name() + " " + EnchantManager.roman(lvl));
            return;
        }
        Msg.send(s, "&c/cenchant list | apply <id> [ур] | book <игрок> <id> [ур]");
    }

    @Override
    public List<String> onTabComplete(CommandSender s, Command cmd, String label, String[] a) {
        switch (cmd.getName().toLowerCase()) {
            case "shadowsmp" -> { if (a.length == 1) return pref(List.of("reload"), a[0]); }
            case "buildspawn" -> { if (a.length == 1) return List.of("confirm"); }
            case "spawn" -> { if (a.length == 1 && s.hasPermission("shadowsmp.spawn.others")) return null; }
            case "talisman" -> {
                if (a.length == 1) return pref(List.of("list", "give"), a[0]);
                if (a.length == 2) return null;
                if (a.length == 3) return pref(plugin.items().talismans().stream().map(ItemDef::shortId).toList(), a[2]);
            }
            case "citem" -> {
                if (a.length == 1) return pref(List.of("list", "give"), a[0]);
                if (a.length == 2) return null;
                if (a.length == 3) return pref(plugin.items().ids(), a[2]);
            }
            case "cenchant" -> {
                List<String> ids = new ArrayList<>(plugin.enchants().ids());
                if (a.length == 1) return pref(List.of("list", "apply", "book"), a[0]);
                if (a[0].equalsIgnoreCase("apply") && a.length == 2) return pref(ids, a[1]);
                if (a[0].equalsIgnoreCase("book") && a.length == 2) return null;
                if (a[0].equalsIgnoreCase("book") && a.length == 3) return pref(ids, a[2]);
            }
        }
        return List.of();
    }

    private static List<String> pref(List<String> l, String p) {
        return l.stream().filter(x -> x.toLowerCase().startsWith(p.toLowerCase())).toList();
    }
}
