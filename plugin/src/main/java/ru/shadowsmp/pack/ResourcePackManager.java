package ru.shadowsmp.pack;

import org.bukkit.Bukkit;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.Listener;
import org.bukkit.event.player.PlayerJoinEvent;
import org.bukkit.event.player.PlayerResourcePackStatusEvent;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Text;

import java.io.InputStream;
import java.net.URI;
import java.net.URLConnection;
import java.security.MessageDigest;
import java.util.HashSet;
import java.util.HexFormat;
import java.util.Set;
import java.util.UUID;

/** Обязательный ресурспак: без него на сервер не пускает. */
public class ResourcePackManager implements Listener {
    private static final UUID PACK_ID = UUID.nameUUIDFromBytes("ShadowSMP-pack".getBytes());
    private final ShadowSMP plugin;
    private final Set<UUID> loaded = new HashSet<>();
    private volatile byte[] hash;
    /** false, если ссылка не открылась — тогда не кикаем, чтобы не закрыть сервер для всех. */
    private volatile boolean reachable = true;

    public ResourcePackManager(ShadowSMP plugin) {
        this.plugin = plugin;
        reload();
    }

    public void reload() {
        hash = null;
        reachable = true;
        String url = url();
        if (url.isBlank()) return;
        String fixed = plugin.getConfig().getString("resource-pack.sha1", "");
        if (!fixed.isBlank()) { hash = HexFormat.of().parseHex(fixed.trim()); return; }
        Bukkit.getScheduler().runTaskAsynchronously(plugin, () -> {
            try {
                URLConnection c = URI.create(url).toURL().openConnection();
                c.setConnectTimeout(10000);
                c.setReadTimeout(30000);
                MessageDigest md = MessageDigest.getInstance("SHA-1");
                try (InputStream in = c.getInputStream()) {
                    byte[] buf = new byte[8192];
                    int r;
                    while ((r = in.read(buf)) > 0) md.update(buf, 0, r);
                }
                hash = md.digest();
                plugin.getLogger().info("Ресурспак найден, SHA-1: " + HexFormat.of().formatHex(hash));
            } catch (Exception e) {
                reachable = false;
                plugin.getLogger().warning("Ресурспак по ссылке недоступен (" + e.getMessage() + ")! Проверь resource-pack.url. Кик за отказ отключён.");
            }
        });
    }

    private String url() {
        return plugin.getConfig().getString("resource-pack.url", "").trim();
    }

    public boolean hasPack(Player p) {
        return url().isBlank() || loaded.contains(p.getUniqueId());
    }

    public void send(Player p) {
        String url = url();
        if (url.isBlank()) return;
        p.setResourcePack(PACK_ID, url, hash, Text.color(plugin.getConfig().getString("resource-pack.prompt",
                "&5&lShadowSMP &7требует ресурспак с кастомными предметами!")), plugin.getConfig().getBoolean("resource-pack.force", true));
    }

    @EventHandler
    public void onJoin(PlayerJoinEvent e) {
        loaded.remove(e.getPlayer().getUniqueId());
        Bukkit.getScheduler().runTaskLater(plugin, () -> { if (e.getPlayer().isOnline()) send(e.getPlayer()); }, 20);
    }

    @EventHandler
    public void onStatus(PlayerResourcePackStatusEvent e) {
        Player p = e.getPlayer();
        switch (e.getStatus()) {
            case SUCCESSFULLY_LOADED -> {
                loaded.add(p.getUniqueId());
                plugin.board().actionBar(p, "&a✔ Ресурспак ShadowSMP загружен");
            }
            case DECLINED, FAILED_DOWNLOAD, INVALID_URL, FAILED_RELOAD, DISCARDED -> {
                if (reachable && plugin.getConfig().getBoolean("resource-pack.kick-on-fail", true) && !p.hasPermission("shadowsmp.pack.bypass")) {
                    String reason = e.getStatus() == PlayerResourcePackStatusEvent.Status.DECLINED
                            ? plugin.getConfig().getString("resource-pack.kick-declined", "&cДля игры на ShadowSMP нужно принять ресурспак!\n&7Сервер → Изменить → Наборы ресурсов: Включены")
                            : plugin.getConfig().getString("resource-pack.kick-failed", "&cНе удалось загрузить ресурспак. Перезайдите.");
                    p.kickPlayer(Text.color(reason));
                }
            }
            default -> {}
        }
    }
}
