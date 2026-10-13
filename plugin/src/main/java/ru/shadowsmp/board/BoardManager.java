package ru.shadowsmp.board;

import net.md_5.bungee.api.ChatMessageType;
import net.md_5.bungee.api.chat.TextComponent;
import org.bukkit.Bukkit;
import org.bukkit.ChatColor;
import org.bukkit.Statistic;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.scoreboard.*;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Text;

import java.util.*;

/** Кастомный TAB (шапка/подвал/ники с префиксами) и скорборд ShadowSMP. */
public class BoardManager implements Listener {
    private static final String[] ENTRIES;

    static {
        ENTRIES = new String[15];
        ChatColor[] c = ChatColor.values();
        for (int i = 0; i < 15; i++) ENTRIES[i] = c[i].toString() + ChatColor.RESET;
    }

    private final ShadowSMP plugin;
    private final Map<UUID, Scoreboard> boards = new HashMap<>();
    private final Set<UUID> hidden = new HashSet<>();
    private LuckPermsHook lp;
    private int frame;

    public BoardManager(ShadowSMP plugin) {
        this.plugin = plugin;
        if (Bukkit.getPluginManager().getPlugin("LuckPerms") != null) {
            try { lp = new LuckPermsHook(); } catch (Throwable t) { lp = null; }
        }
        Bukkit.getScheduler().runTaskTimer(plugin, this::update, 20, 20);
        Bukkit.getScheduler().runTaskTimer(plugin, this::animate, 5, plugin.getConfig().getLong("scoreboard.title-speed", 4));
    }

    public String prefix(Player p) {
        return lp == null ? "" : Text.color(lp.prefix(p));
    }

    public String group(Player p) {
        return lp == null ? (p.isOp() ? "admin" : "default") : lp.group(p);
    }

    public String rankName(Player p) {
        String g = group(p);
        return Text.color(plugin.getConfig().getString("scoreboard.rank-names." + g, "&7" + g));
    }

    public void actionBar(Player p, String msg) {
        p.spigot().sendMessage(ChatMessageType.ACTION_BAR, TextComponent.fromLegacy(Text.color(msg)));
    }

    public String apply(Player p, String s) {
        long played = p.getStatistic(Statistic.PLAY_ONE_MINUTE) / 20;
        return Text.color(s
                .replace("{player}", p.getName())
                .replace("{rank}", rankName(p))
                .replace("{prefix}", prefix(p))
                .replace("{coins}", Text.formatNumber(plugin.economy().get(p.getUniqueId(), false)))
                .replace("{shadowcoins}", Text.formatNumber(plugin.economy().get(p.getUniqueId(), true)))
                .replace("{online}", String.valueOf(Bukkit.getOnlinePlayers().size()))
                .replace("{max}", String.valueOf(Bukkit.getMaxPlayers()))
                .replace("{ping}", String.valueOf(p.getPing()))
                .replace("{kills}", String.valueOf(p.getStatistic(Statistic.PLAYER_KILLS)))
                .replace("{deaths}", String.valueOf(p.getStatistic(Statistic.DEATHS)))
                .replace("{mobs}", String.valueOf(p.getStatistic(Statistic.MOB_KILLS)))
                .replace("{playtime}", Text.formatTime(played))
                .replace("{world}", p.getWorld().getName())
                .replace("{x}", String.valueOf(p.getLocation().getBlockX()))
                .replace("{y}", String.valueOf(p.getLocation().getBlockY()))
                .replace("{z}", String.valueOf(p.getLocation().getBlockZ()))
                .replace("{event}", plugin.events().status())
                .replace("{talisman}", talismanName(p)));
    }

    private String talismanName(Player p) {
        var list = plugin.talismans().activeTalismans(p);
        return list.isEmpty() ? "&8нет" : list.get(0).name();
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        Player p = e.getPlayer();
        Scoreboard sb = Bukkit.getScoreboardManager().getNewScoreboard();
        Objective o = sb.registerNewObjective("shadowsmp", Criteria.DUMMY, Text.color("&5&lShadowSMP"));
        o.setDisplaySlot(DisplaySlot.SIDEBAR);
        boards.put(p.getUniqueId(), sb);
        if (plugin.getConfig().getBoolean("scoreboard.enabled", true)) p.setScoreboard(sb);
        Bukkit.getScheduler().runTaskLater(plugin, this::update, 5);
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        boards.remove(e.getPlayer().getUniqueId());
    }

    public void toggle(Player p) {
        if (!hidden.remove(p.getUniqueId())) {
            hidden.add(p.getUniqueId());
            p.setScoreboard(Bukkit.getScoreboardManager().getNewScoreboard());
        } else {
            Scoreboard sb = boards.get(p.getUniqueId());
            if (sb != null) p.setScoreboard(sb);
        }
    }

    private void animate() {
        List<String> frames = plugin.getConfig().getStringList("scoreboard.title-frames");
        if (frames.isEmpty()) return;
        frame = (frame + 1) % frames.size();
        String title = Text.color(frames.get(frame));
        for (Scoreboard sb : boards.values()) {
            Objective o = sb.getObjective("shadowsmp");
            if (o != null) o.setDisplayName(title);
        }
    }

    public void update() {
        List<String> lines = plugin.getConfig().getStringList("scoreboard.lines");
        List<String> header = plugin.getConfig().getStringList("tab.header");
        List<String> footer = plugin.getConfig().getStringList("tab.footer");
        String listFormat = plugin.getConfig().getString("tab.player-format", "{prefix}&f{player}");
        for (Player p : Bukkit.getOnlinePlayers()) {
            // TAB
            if (plugin.getConfig().getBoolean("tab.enabled", true)) {
                p.setPlayerListHeaderFooter(apply(p, String.join("\n", header)), apply(p, String.join("\n", footer)));
                p.setPlayerListName(apply(p, listFormat));
            }
            // Скорборд
            Scoreboard sb = boards.get(p.getUniqueId());
            if (sb == null || hidden.contains(p.getUniqueId())) continue;
            Objective o = sb.getObjective("shadowsmp");
            boolean logged = plugin.auth().isLoggedIn(p);
            List<String> show = logged ? lines : plugin.getConfig().getStringList("scoreboard.login-lines");
            int n = Math.min(15, show.size());
            for (int i = 0; i < 15; i++) {
                Team t = sb.getTeam("line" + i);
                if (i >= n) {
                    if (t != null) { sb.resetScores(ENTRIES[i]); t.unregister(); }
                    continue;
                }
                if (t == null) { t = sb.registerNewTeam("line" + i); t.addEntry(ENTRIES[i]); }
                t.setPrefix(apply(p, show.get(i)));
                o.getScore(ENTRIES[i]).setScore(n - i);
            }
            // Префиксы над головой и сортировка в табе
            for (Team old : new ArrayList<>(sb.getTeams())) {
                if (old.getName().startsWith("r") && old.getEntries().stream().noneMatch(en -> Bukkit.getPlayerExact(en) != null))
                    old.unregister();
            }
            for (Player other : Bukkit.getOnlinePlayers()) {
                int w = lp == null ? (other.isOp() ? 100 : 0) : lp.weight(other);
                String name = String.format("r%03d%s", Math.max(0, 999 - w), other.getName());
                if (name.length() > 64) name = name.substring(0, 64);
                Team t = sb.getEntryTeam(other.getName());
                if (t != null && !t.getName().equals(name)) { t.unregister(); t = null; }
                if (t == null) {
                    t = sb.getTeam(name);
                    if (t == null) t = sb.registerNewTeam(name);
                    t.addEntry(other.getName());
                }
                t.setPrefix(prefix(other));
            }
        }
    }
}
