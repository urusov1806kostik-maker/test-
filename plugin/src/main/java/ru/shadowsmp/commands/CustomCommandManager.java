package ru.shadowsmp.commands;

import org.bukkit.Bukkit;
import org.bukkit.command.*;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.Player;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Actions;
import ru.shadowsmp.util.Msg;
import ru.shadowsmp.util.Text;

import java.io.File;
import java.io.IOException;
import java.lang.reflect.Field;
import java.util.*;

/** Кастомные команды из commands.yml (можно объединять несколько команд в одну). /ccmd для управления в игре. */
public class CustomCommandManager implements CommandExecutor, TabCompleter {
    private final ShadowSMP plugin;
    private final File file;
    private YamlConfiguration data;
    private final List<Command> registered = new ArrayList<>();
    private final Map<String, Long> cooldowns = new HashMap<>();

    public CustomCommandManager(ShadowSMP plugin) {
        this.plugin = plugin;
        this.file = new File(plugin.getDataFolder(), "commands.yml");
        reload();
    }

    private CommandMap map() {
        try {
            return (CommandMap) Bukkit.getServer().getClass().getMethod("getCommandMap").invoke(Bukkit.getServer());
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    @SuppressWarnings("unchecked")
    private Map<String, Command> known(CommandMap cm) {
        try {
            Field f = SimpleCommandMap.class.getDeclaredField("knownCommands");
            f.setAccessible(true);
            return (Map<String, Command>) f.get(cm);
        } catch (Exception e) {
            plugin.getLogger().warning("Нет доступа к списку команд: " + e.getMessage());
            return null;
        }
    }

    private void unregisterAll() {
        CommandMap cm = map();
        Map<String, Command> known = known(cm);
        for (Command c : registered) {
            c.unregister(cm);
            if (known != null) known.values().removeIf(v -> v == c);
        }
        registered.clear();
    }

    public void reload() {
        unregisterAll();
        data = YamlConfiguration.loadConfiguration(file);
        ConfigurationSection sec = data.getConfigurationSection("commands");
        CommandMap cm = map();
        Map<String, Command> known = known(cm);
        if (sec != null) for (String name : sec.getKeys(false)) {
            ConfigurationSection c = sec.getConfigurationSection(name);
            Dynamic cmd = new Dynamic(name.toLowerCase(), c);
            cm.register("shadowsmp", cmd);
            registered.add(cmd);
            // кастом-команда важнее одноимённых команд других плагинов (например /rules у EssentialsX)
            if (known != null) {
                known.put(cmd.getName(), cmd);
                for (String al : cmd.getAliases()) known.put(al.toLowerCase(), cmd);
            }
        }
        try { Bukkit.getServer().getClass().getMethod("syncCommands").invoke(Bukkit.getServer()); } catch (Exception ignored) {}
        Bukkit.getOnlinePlayers().forEach(Player::updateCommands);
        plugin.getLogger().info("Кастомных команд: " + registered.size());
    }

    private class Dynamic extends Command {
        private final ConfigurationSection c;

        Dynamic(String name, ConfigurationSection c) {
            super(name, Text.color(c.getString("description", "Команда ShadowSMP")), "/" + name, c.getStringList("aliases"));
            this.c = c;
            String perm = c.getString("permission", "");
            if (!perm.isBlank()) setPermission(perm);
        }

        @Override
        public boolean execute(CommandSender s, String label, String[] args) {
            if (!(s instanceof Player p)) { s.sendMessage("Только для игроков."); return true; }
            String perm = c.getString("permission", "");
            if (!perm.isBlank() && !p.hasPermission(perm)) {
                Msg.send(p, c.getString("no-permission", "&cНет прав."));
                return true;
            }
            int cd = c.getInt("cooldown", 0);
            String key = p.getUniqueId() + ":" + getName();
            long now = System.currentTimeMillis();
            if (cd > 0 && !p.hasPermission("shadowsmp.cooldown.bypass")) {
                long left = cooldowns.getOrDefault(key, 0L) + cd * 1000L - now;
                if (left > 0) { Msg.send(p, "&cПодожди ещё " + Text.formatTime(left / 1000 + 1)); return true; }
                cooldowns.put(key, now);
            }
            double price = c.getDouble("price", 0);
            if (price > 0) {
                boolean shadow = c.getBoolean("price-shadowcoins", false);
                if (!plugin.economy().take(p.getUniqueId(), shadow, price)) {
                    Msg.send(p, "&cНужно " + plugin.economy().format(price, shadow));
                    return true;
                }
            }
            Actions.run(p, c.getStringList("actions"), args);
            return true;
        }
    }

    private void save() {
        try { data.save(file); } catch (IOException e) { plugin.getLogger().warning("commands.yml: " + e.getMessage()); }
    }

    @Override
    public boolean onCommand(CommandSender s, Command cmd, String label, String[] a) {
        if (a.length == 0) {
            for (String l : List.of("&5&lКастом команды:", "&f/ccmd create <имя> <действие> &7— создать",
                    "&f/ccmd add <имя> <действие> &7— добавить действие (объединение команд)",
                    "&f/ccmd perm <имя> <право|none> &7| &f/ccmd cooldown <имя> <сек>", "&f/ccmd alias <имя> <алиас>",
                    "&f/ccmd delete <имя> &7| &f/ccmd info <имя> &7| &f/ccmd list &7| &f/ccmd reload",
                    "&7Действия: [player] cmd, [console] cmd, [message] txt, [broadcast] txt, [title] a;b,",
                    "&7[actionbar] txt, [sound] X, [delay] тики, [give] id*n, [coins] n, [effect] SPEED:1:200, [spawn], [menu] shop",
                    "&7Плейсхолдеры: {player} {args} {arg1} {arg2}..."))
                s.sendMessage(Text.color(l));
            return true;
        }
        String sub = a[0].toLowerCase();
        if (sub.equals("list")) { Msg.send(s, "&7Команды: &f" + String.join(", ", names())); return true; }
        if (sub.equals("reload")) { reload(); Msg.send(s, "&aКоманды перезагружены."); return true; }
        if (a.length < 2) { Msg.send(s, "&cУкажи имя команды."); return true; }
        String name = a[1].toLowerCase().replace("/", "");
        String path = "commands." + name;
        String rest = a.length > 2 ? String.join(" ", Arrays.copyOfRange(a, 2, a.length)) : "";
        switch (sub) {
            case "create" -> {
                if (data.contains(path)) { Msg.send(s, "&cУже есть."); return true; }
                data.set(path + ".description", "Кастом команда");
                data.set(path + ".permission", "");
                data.set(path + ".cooldown", 0);
                data.set(path + ".aliases", new ArrayList<String>());
                data.set(path + ".actions", rest.isBlank() ? new ArrayList<String>() : new ArrayList<>(List.of(rest)));
            }
            case "add" -> {
                List<String> acts = new ArrayList<>(data.getStringList(path + ".actions"));
                acts.add(rest);
                data.set(path + ".actions", acts);
            }
            case "perm" -> data.set(path + ".permission", rest.equalsIgnoreCase("none") ? "" : rest);
            case "cooldown" -> data.set(path + ".cooldown", Integer.parseInt(rest.trim()));
            case "alias" -> {
                List<String> al = new ArrayList<>(data.getStringList(path + ".aliases"));
                al.add(rest.trim());
                data.set(path + ".aliases", al);
            }
            case "delete" -> data.set(path, null);
            case "info" -> {
                s.sendMessage(Text.color("&5/" + name + " &7права: &f" + data.getString(path + ".permission", "") + " &7кд: &f" + data.getInt(path + ".cooldown")));
                List<String> acts = data.getStringList(path + ".actions");
                for (int i = 0; i < acts.size(); i++) s.sendMessage(Text.color("&7" + i + ": &f" + acts.get(i)));
                return true;
            }
            default -> { Msg.send(s, "&cНеизвестная подкоманда."); return true; }
        }
        save();
        reload();
        Msg.send(s, "&aГотово: /" + name);
        return true;
    }

    private List<String> names() {
        ConfigurationSection sec = data.getConfigurationSection("commands");
        return sec == null ? List.of() : new ArrayList<>(sec.getKeys(false));
    }

    @Override
    public List<String> onTabComplete(CommandSender s, Command c, String l, String[] a) {
        if (a.length == 1) return pref(List.of("create", "add", "perm", "cooldown", "alias", "delete", "info", "list", "reload"), a[0]);
        if (a.length == 2 && !a[0].equalsIgnoreCase("create")) return pref(names(), a[1]);
        if (a.length == 3 && (a[0].equalsIgnoreCase("create") || a[0].equalsIgnoreCase("add")))
            return pref(List.of("[player]", "[console]", "[message]", "[broadcast]", "[title]", "[actionbar]", "[sound]", "[delay]", "[give]", "[coins]", "[shadowcoins]", "[effect]", "[spawn]", "[menu]"), a[2]);
        return List.of();
    }

    private static List<String> pref(List<String> l, String p) {
        return l.stream().filter(x -> x.toLowerCase().startsWith(p.toLowerCase())).toList();
    }
}
