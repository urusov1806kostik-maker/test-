package ru.shadowsmp.auth;

import org.bukkit.Bukkit;
import org.bukkit.Location;
import org.bukkit.command.*;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.EntityDamageEvent;
import org.bukkit.event.entity.EntityPickupItemEvent;
import org.bukkit.event.entity.FoodLevelChangeEvent;
import org.bukkit.event.inventory.InventoryClickEvent;
import org.bukkit.event.inventory.InventoryOpenEvent;
import org.bukkit.event.player.*;
import org.bukkit.potion.PotionEffect;
import org.bukkit.potion.PotionEffectType;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Msg;
import ru.shadowsmp.util.Text;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.io.File;
import java.io.IOException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.*;

/** Регистрация и логин: /register, /login, /changepassword, /unregister (админ). */
public class AuthManager implements Listener, CommandExecutor {
    private static final Set<String> ALLOWED = Set.of("/login", "/l", "/log", "/register", "/reg");
    private final ShadowSMP plugin;
    private final File file;
    private final YamlConfiguration data;
    private final Set<UUID> logged = new HashSet<>();
    private final Map<UUID, Integer> attempts = new HashMap<>();
    private final Map<UUID, Long> joinTime = new HashMap<>();

    public AuthManager(ShadowSMP plugin) {
        this.plugin = plugin;
        this.file = new File(plugin.getDataFolder(), "data/auth.yml");
        this.data = YamlConfiguration.loadConfiguration(file);
        Bukkit.getScheduler().runTaskTimer(plugin, this::remind, 40, 60);
        // после /reload считаем всех онлайн-игроков вошедшими
        for (Player p : Bukkit.getOnlinePlayers()) logged.add(p.getUniqueId());
    }

    private boolean enabled() {
        return plugin.getConfig().getBoolean("auth.enabled", true);
    }

    public boolean isLoggedIn(Player p) {
        return !enabled() || logged.contains(p.getUniqueId());
    }

    private String key(Player p) {
        return "users." + p.getName().toLowerCase();
    }

    public boolean isRegistered(Player p) {
        return data.contains(key(p) + ".hash");
    }

    private void save() {
        try {
            file.getParentFile().mkdirs();
            data.save(file);
        } catch (IOException e) {
            plugin.getLogger().warning("auth.yml: " + e.getMessage());
        }
    }

    private static String hash(String pass, String saltHex) {
        try {
            byte[] salt = HexFormat.of().parseHex(saltHex);
            PBEKeySpec spec = new PBEKeySpec(pass.toCharArray(), salt, 65536, 256);
            return HexFormat.of().formatHex(SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded());
        } catch (Exception e) {
            throw new IllegalStateException(e);
        }
    }

    private void setPassword(Player p, String pass) {
        byte[] salt = new byte[16];
        new SecureRandom().nextBytes(salt);
        String s = HexFormat.of().formatHex(salt);
        data.set(key(p) + ".salt", s);
        data.set(key(p) + ".hash", hash(pass, s));
        data.set(key(p) + ".uuid", p.getUniqueId().toString());
        save();
    }

    private boolean check(Player p, String pass) {
        String salt = data.getString(key(p) + ".salt"), h = data.getString(key(p) + ".hash");
        if (salt == null || h == null) return false;
        return MessageDigest.isEqual(hash(pass, salt).getBytes(), h.getBytes());
    }

    private void success(Player p, String msg) {
        logged.add(p.getUniqueId());
        attempts.remove(p.getUniqueId());
        joinTime.remove(p.getUniqueId());
        data.set(key(p) + ".ip", p.getAddress() == null ? "" : p.getAddress().getAddress().getHostAddress());
        data.set(key(p) + ".last-login", System.currentTimeMillis());
        save();
        p.removePotionEffect(PotionEffectType.BLINDNESS);
        p.sendTitle(Text.color("<g:#7B2FF7:#F107A3>&lShadowSMP</g>"), Text.color(msg), 5, 40, 10);
        p.playSound(p.getLocation(), org.bukkit.Sound.ENTITY_PLAYER_LEVELUP, 1f, 1.2f);
        Msg.send(p, msg);
    }

    @Override
    public boolean onCommand(CommandSender s, Command cmd, String label, String[] a) {
        String n = cmd.getName().toLowerCase();
        if (n.equals("unregister")) {
            if (a.length < 1) { Msg.send(s, "&c/unregister <ник>"); return true; }
            data.set("users." + a[0].toLowerCase(), null);
            save();
            Player t = Bukkit.getPlayerExact(a[0]);
            if (t != null) t.kickPlayer(Text.color("&cВаш аккаунт сброшен. Зарегистрируйтесь заново."));
            Msg.send(s, "&aАккаунт " + a[0] + " удалён.");
            return true;
        }
        if (!(s instanceof Player p)) return true;
        int min = plugin.getConfig().getInt("auth.min-password-length", 4);
        switch (n) {
            case "register" -> {
                if (logged.contains(p.getUniqueId()) && isRegistered(p)) { Msg.send(p, "&cВы уже вошли."); return true; }
                if (isRegistered(p)) { Msg.send(p, "&cВы уже зарегистрированы! &f/login <пароль>"); return true; }
                if (a.length < 2) { Msg.send(p, "&c/register <пароль> <повтор пароля>"); return true; }
                if (!a[0].equals(a[1])) { Msg.send(p, "&cПароли не совпадают."); return true; }
                if (a[0].length() < min) { Msg.send(p, "&cПароль слишком короткий (мин. " + min + ")."); return true; }
                if (a[0].equalsIgnoreCase(p.getName())) { Msg.send(p, "&cПароль не должен совпадать с ником."); return true; }
                setPassword(p, a[0]);
                success(p, "&aВы успешно зарегистрировались!");
            }
            case "login" -> {
                if (logged.contains(p.getUniqueId())) { Msg.send(p, "&cВы уже вошли."); return true; }
                if (!isRegistered(p)) { Msg.send(p, "&cСначала зарегистрируйтесь: &f/register <пароль> <пароль>"); return true; }
                if (a.length < 1) { Msg.send(p, "&c/login <пароль>"); return true; }
                if (check(p, a[0])) success(p, "&aВы успешно вошли!");
                else {
                    int at = attempts.merge(p.getUniqueId(), 1, Integer::sum);
                    int max = plugin.getConfig().getInt("auth.max-attempts", 5);
                    if (at >= max) p.kickPlayer(Text.color("&cСлишком много неверных попыток."));
                    else Msg.send(p, "&cНеверный пароль! Осталось попыток: " + (max - at));
                }
            }
            case "changepassword" -> {
                if (!logged.contains(p.getUniqueId())) return true;
                if (a.length < 2) { Msg.send(p, "&c/changepassword <старый> <новый>"); return true; }
                if (!check(p, a[0])) { Msg.send(p, "&cСтарый пароль неверный."); return true; }
                if (a[1].length() < min) { Msg.send(p, "&cПароль слишком короткий."); return true; }
                setPassword(p, a[1]);
                Msg.send(p, "&aПароль изменён!");
            }
            case "logout" -> {
                logged.remove(p.getUniqueId());
                data.set(key(p) + ".ip", null);
                save();
                p.kickPlayer(Text.color("&7Вы вышли из аккаунта."));
            }
        }
        return true;
    }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onJoin(PlayerJoinEvent e) {
        Player p = e.getPlayer();
        logged.remove(p.getUniqueId());
        if (!enabled()) { logged.add(p.getUniqueId()); return; }
        // сессия: тот же IP в течение N минут — входим автоматически
        long sessionMin = plugin.getConfig().getLong("auth.session-minutes", 30);
        String ip = p.getAddress() == null ? "" : p.getAddress().getAddress().getHostAddress();
        long last = data.getLong(key(p) + ".last-login", 0);
        if (isRegistered(p) && sessionMin > 0 && ip.equals(data.getString(key(p) + ".ip"))
                && System.currentTimeMillis() - last < sessionMin * 60_000) {
            Bukkit.getScheduler().runTaskLater(plugin, () -> success(p, "&aАвтоматический вход (сессия)."), 10);
            return;
        }
        joinTime.put(p.getUniqueId(), System.currentTimeMillis());
        p.addPotionEffect(new PotionEffect(PotionEffectType.BLINDNESS, 20 * 600, 0, false, false, false));
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        if (logged.contains(e.getPlayer().getUniqueId())) {
            data.set(key(e.getPlayer()) + ".last-login", System.currentTimeMillis());
            save();
        }
        logged.remove(e.getPlayer().getUniqueId());
        joinTime.remove(e.getPlayer().getUniqueId());
        attempts.remove(e.getPlayer().getUniqueId());
    }

    private void remind() {
        long timeout = plugin.getConfig().getLong("auth.timeout-seconds", 90) * 1000;
        for (Player p : Bukkit.getOnlinePlayers()) {
            if (isLoggedIn(p)) continue;
            Long t = joinTime.get(p.getUniqueId());
            if (t != null && System.currentTimeMillis() - t > timeout) {
                p.kickPlayer(Text.color("&cВремя на вход истекло."));
                continue;
            }
            boolean reg = isRegistered(p);
            p.sendTitle(Text.color("<g:#7B2FF7:#F107A3>&lShadowSMP</g>"),
                    Text.color(reg ? "&7Войдите: &f/login <пароль>" : "&7Регистрация: &f/register <пароль> <пароль>"), 0, 70, 0);
            Msg.send(p, reg ? "&7Войдите: &f/login <пароль>" : "&7Зарегистрируйтесь: &f/register <пароль> <повтор>");
        }
    }

    // ===== блокировки до входа =====
    @EventHandler(priority = EventPriority.LOWEST)
    public void onMove(PlayerMoveEvent e) {
        if (isLoggedIn(e.getPlayer()) || e.getTo() == null) return;
        Location f = e.getFrom(), t = e.getTo();
        if (f.getX() != t.getX() || f.getZ() != t.getZ() || t.getY() > f.getY()) {
            Location back = f.clone();
            back.setYaw(t.getYaw());
            back.setPitch(t.getPitch());
            e.setTo(back);
        }
    }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onChat(AsyncPlayerChatEvent e) {
        if (!isLoggedIn(e.getPlayer())) { e.setCancelled(true); Msg.send(e.getPlayer(), "&cСначала войдите в аккаунт."); }
    }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onCommand(PlayerCommandPreprocessEvent e) {
        if (isLoggedIn(e.getPlayer())) return;
        String c = e.getMessage().split(" ")[0].toLowerCase();
        if (c.contains(":")) c = "/" + c.substring(c.indexOf(':') + 1);
        if (!ALLOWED.contains(c)) { e.setCancelled(true); Msg.send(e.getPlayer(), "&cСначала войдите в аккаунт."); }
    }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onInteract(PlayerInteractEvent e) { if (!isLoggedIn(e.getPlayer())) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onInteractEntity(PlayerInteractEntityEvent e) { if (!isLoggedIn(e.getPlayer())) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onDrop(PlayerDropItemEvent e) { if (!isLoggedIn(e.getPlayer())) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onPickup(EntityPickupItemEvent e) { if (e.getEntity() instanceof Player p && !isLoggedIn(p)) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onSwap(PlayerSwapHandItemsEvent e) { if (!isLoggedIn(e.getPlayer())) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onInv(InventoryClickEvent e) { if (e.getWhoClicked() instanceof Player p && !isLoggedIn(p)) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onInvOpen(InventoryOpenEvent e) { if (e.getPlayer() instanceof Player p && !isLoggedIn(p)) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onBreak(BlockBreakEvent e) { if (!isLoggedIn(e.getPlayer())) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onPlace(BlockPlaceEvent e) { if (!isLoggedIn(e.getPlayer())) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onDamage(EntityDamageEvent e) { if (e.getEntity() instanceof Player p && !isLoggedIn(p)) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onAttack(EntityDamageByEntityEvent e) { if (e.getDamager() instanceof Player p && !isLoggedIn(p)) e.setCancelled(true); }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onFood(FoodLevelChangeEvent e) { if (e.getEntity() instanceof Player p && !isLoggedIn(p)) e.setCancelled(true); }
}
