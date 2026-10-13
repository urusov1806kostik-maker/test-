package ru.shadowsmp.events;

import org.bukkit.*;
import org.bukkit.attribute.Attribute;
import org.bukkit.block.Block;
import org.bukkit.block.Chest;
import org.bukkit.boss.BarColor;
import org.bukkit.boss.BarStyle;
import org.bukkit.boss.BossBar;
import org.bukkit.command.*;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.entity.*;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.EntityDeathEvent;
import org.bukkit.event.inventory.InventoryOpenEvent;
import org.bukkit.event.player.AsyncPlayerChatEvent;
import org.bukkit.inventory.EquipmentSlot;
import org.bukkit.inventory.ItemStack;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.potion.PotionEffect;
import org.bukkit.potion.PotionEffectType;
import org.bukkit.scheduler.BukkitTask;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Keys;
import ru.shadowsmp.util.Msg;
import ru.shadowsmp.util.Text;

import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Ивенты: chat (кто быстрее напишет), math (пример), hunt (охота на мобов), boss (босс),
 * treasure (сундук с сокровищами), drop (дроп-пати на спавне). Авто-запуск по таймеру.
 */
public class EventManager implements Listener, CommandExecutor, TabCompleter {
    public static final List<String> TYPES = List.of("chat", "math", "hunt", "boss", "treasure", "drop");
    private final ShadowSMP plugin;
    private String active;
    private long endAt;
    private BossBar bar;
    private BukkitTask timer, autoTask;
    private String answer;
    private final Map<UUID, Double> score = new HashMap<>();
    private LivingEntity boss;
    private Location treasure;

    public EventManager(ShadowSMP plugin) {
        this.plugin = plugin;
        scheduleAuto();
    }

    public void scheduleAuto() {
        if (autoTask != null) autoTask.cancel();
        long min = plugin.getConfig().getLong("events.auto-interval-minutes", 30);
        if (min <= 0) return;
        autoTask = Bukkit.getScheduler().runTaskTimer(plugin, () -> {
            if (active != null || Bukkit.getOnlinePlayers().size() < plugin.getConfig().getInt("events.min-players", 2)) return;
            List<String> pool = plugin.getConfig().getStringList("events.auto-types");
            if (pool.isEmpty()) pool = TYPES;
            start(pool.get(ThreadLocalRandom.current().nextInt(pool.size())));
        }, min * 1200, min * 1200);
    }

    public String status() {
        if (active == null) return Text.color("&8нет");
        return Text.color("&d" + title(active) + (endAt > 0 ? " &7" + Math.max(0, (endAt - System.currentTimeMillis()) / 1000) + "с" : ""));
    }

    private String title(String type) {
        return switch (type) {
            case "chat" -> "Быстрые пальцы";
            case "math" -> "Математик";
            case "hunt" -> "Охота на мобов";
            case "boss" -> "Тёмный Повелитель";
            case "treasure" -> "Сокровища";
            case "drop" -> "Дроп-пати";
            default -> type;
        };
    }

    private ConfigurationSection cfg(String type) {
        ConfigurationSection c = plugin.getConfig().getConfigurationSection("events.types." + type);
        return c != null ? c : plugin.getConfig().createSection("events.types." + type);
    }

    private void announce(String... lines) {
        Bukkit.broadcastMessage(Text.color("&8&m                                                  "));
        Bukkit.broadcastMessage(Text.color("   <g:#7B2FF7:#F107A3>&l⚑ ИВЕНТ: " + title(active).toUpperCase() + "</g>"));
        for (String l : lines) Bukkit.broadcastMessage(Text.color("   " + l));
        Bukkit.broadcastMessage(Text.color("&8&m                                                  "));
        for (Player p : Bukkit.getOnlinePlayers()) p.playSound(p.getLocation(), Sound.UI_TOAST_CHALLENGE_COMPLETE, 0.7f, 1.2f);
    }

    private void reward(Player p, String type, int place) {
        ConfigurationSection c = cfg(type);
        String path = "reward" + (place > 1 ? "-" + place : "");
        double coins = c.getDouble(path + ".coins", place == 1 ? 100 : 0);
        double sc = c.getDouble(path + ".shadowcoins", place == 1 ? 5 : 0);
        if (coins > 0) plugin.economy().add(p.getUniqueId(), false, coins);
        if (sc > 0) plugin.economy().add(p.getUniqueId(), true, sc);
        for (String item : c.getStringList(path + ".items")) {
            String[] g = item.split("\\*");
            ItemStack it = plugin.items().resolve(g[0]);
            if (it == null) continue;
            it.setAmount(g.length > 1 ? Integer.parseInt(g[1].trim()) : 1);
            p.getInventory().addItem(it).values().forEach(l -> p.getWorld().dropItem(p.getLocation(), l));
        }
        Msg.send(p, "&aНаграда: " + (coins > 0 ? plugin.economy().format(coins, false) + " " : "") + (sc > 0 ? plugin.economy().format(sc, true) : ""));
    }

    public boolean start(String type) {
        if (active != null || !TYPES.contains(type)) return false;
        active = type;
        score.clear();
        ThreadLocalRandom r = ThreadLocalRandom.current();
        int duration = cfg(type).getInt("duration-seconds", switch (type) {
            case "hunt" -> 300; case "boss" -> 600; case "treasure" -> 900; case "drop" -> 40; default -> 60;
        });
        endAt = System.currentTimeMillis() + duration * 1000L;
        bar = Bukkit.createBossBar(Text.color("&d&l" + title(type)), BarColor.PURPLE, BarStyle.SEGMENTED_10);
        Bukkit.getOnlinePlayers().forEach(bar::addPlayer);
        switch (type) {
            case "chat" -> {
                String chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghkmnpqrstuvwxyz23456789";
                StringBuilder sb = new StringBuilder();
                for (int i = 0; i < 8; i++) sb.append(chars.charAt(r.nextInt(chars.length())));
                answer = sb.toString();
                announce("&7Первый, кто напишет в чат:", "&f&l" + answer, "&7получит награду!");
            }
            case "math" -> {
                int a = r.nextInt(10, 99), b = r.nextInt(10, 99), c = r.nextInt(2, 9);
                answer = String.valueOf(a + b * c);
                announce("&7Реши пример и напиши ответ в чат:", "&f&l" + a + " + " + b + " × " + c + " = ?");
            }
            case "hunt" -> announce("&7Убей как можно больше мобов за &f" + duration / 60 + " мин&7!", "&7Топ-3 получат награды.");
            case "boss" -> {
                Location l = plugin.spawn().get().clone().add(cfg(type).getDouble("offset-x", 0), 0, cfg(type).getDouble("offset-z", 40));
                if (cfg(type).isLocation("location")) l = cfg(type).getLocation("location");
                l.getChunk().load();
                l = l.getWorld().getHighestBlockAt(l).getLocation().add(0.5, 1, 0.5);
                boss = spawnBoss(l);
                announce("&7На координатах &f" + l.getBlockX() + " " + l.getBlockY() + " " + l.getBlockZ() + " &7появился босс!",
                        "&7Награда тем, кто нанесёт больше всего урона.");
            }
            case "treasure" -> {
                World w = plugin.spawn().get().getWorld();
                int min = cfg(type).getInt("min-distance", 300), max = cfg(type).getInt("max-distance", 1200);
                double ang = r.nextDouble(Math.PI * 2);
                int dist = r.nextInt(min, max);
                Location c = plugin.spawn().get().clone().add(Math.cos(ang) * dist, 0, Math.sin(ang) * dist);
                c.getChunk().load();
                Block b = w.getHighestBlockAt(c).getRelative(0, 1, 0);
                b.setType(Material.CHEST);
                Chest chest = (Chest) b.getState();
                chest.getPersistentDataContainer().set(Keys.TREASURE, PersistentDataType.BYTE, (byte) 1);
                chest.setCustomName(Text.color("&6&lСокровища ShadowSMP"));
                chest.update();
                for (String item : cfg(type).getStringList("loot")) {
                    String[] g = item.split("\\*");
                    ItemStack it = plugin.items().resolve(g[0]);
                    if (it == null) continue;
                    it.setAmount(g.length > 1 ? Integer.parseInt(g[1].trim()) : 1);
                    ((Chest) b.getState()).getBlockInventory().addItem(it);
                }
                treasure = b.getLocation();
                w.spawnParticle(Particle.END_ROD, treasure.clone().add(0.5, 1, 0.5), 50, 0.2, 3, 0.2, 0.01);
                announce("&7Сундук с сокровищами спрятан на:", "&f&lX: " + b.getX() + " Y: " + b.getY() + " Z: " + b.getZ(),
                        "&7Первый, кто откроет — заберёт всё!");
            }
            case "drop" -> announce("&7На спавне начинается &fдроп-пати&7!", "&7Беги на &f/spawn &7— с неба падают предметы!");
        }
        timer = Bukkit.getScheduler().runTaskTimer(plugin, this::tick, 20, 20);
        return true;
    }

    private LivingEntity spawnBoss(Location l) {
        ConfigurationSection c = cfg("boss");
        WitherSkeleton ws = l.getWorld().spawn(l, WitherSkeleton.class, e -> {
            double hp = c.getDouble("health", 400);
            e.getAttribute(Attribute.MAX_HEALTH).setBaseValue(Math.min(1024, hp));
            e.setHealth(Math.min(1024, hp));
            e.getAttribute(Attribute.ATTACK_DAMAGE).setBaseValue(c.getDouble("damage", 14));
            if (e.getAttribute(Attribute.SCALE) != null) e.getAttribute(Attribute.SCALE).setBaseValue(c.getDouble("scale", 1.8));
            e.setCustomName(Text.color(c.getString("name", "&5&l☠ Тёмный Повелитель")));
            e.setCustomNameVisible(true);
            e.setRemoveWhenFarAway(false);
            e.setPersistent(true);
            e.getEquipment().setItem(EquipmentSlot.HAND, new ItemStack(Material.NETHERITE_SWORD));
            e.getEquipment().setItem(EquipmentSlot.HEAD, new ItemStack(Material.NETHERITE_HELMET));
            e.getEquipment().setItem(EquipmentSlot.CHEST, new ItemStack(Material.NETHERITE_CHESTPLATE));
            e.getEquipment().setItemInMainHandDropChance(0f);
            e.getEquipment().setHelmetDropChance(0f);
            e.getEquipment().setChestplateDropChance(0f);
            e.addPotionEffect(new PotionEffect(PotionEffectType.FIRE_RESISTANCE, PotionEffect.INFINITE_DURATION, 0));
            e.addPotionEffect(new PotionEffect(PotionEffectType.SPEED, PotionEffect.INFINITE_DURATION, 0));
            e.getPersistentDataContainer().set(Keys.BOSS, PersistentDataType.BYTE, (byte) 1);
        });
        l.getWorld().strikeLightningEffect(l);
        return ws;
    }

    private void tick() {
        if (active == null) return;
        long left = endAt - System.currentTimeMillis();
        long total = cfg(active).getInt("duration-seconds", 60) * 1000L;
        Bukkit.getOnlinePlayers().forEach(p -> { if (!bar.getPlayers().contains(p)) bar.addPlayer(p); });
        if (active.equals("boss") && boss != null && boss.isValid()) {
            double max = boss.getAttribute(Attribute.MAX_HEALTH).getValue();
            bar.setProgress(Math.max(0, Math.min(1, boss.getHealth() / max)));
            bar.setTitle(Text.color("&5&l☠ Тёмный Повелитель &7— &c" + (int) boss.getHealth() + "❤ &7— " + Text.formatTime(left / 1000)));
            if (ThreadLocalRandom.current().nextInt(5) == 0) bossAbility();
        } else {
            bar.setProgress(Math.max(0, Math.min(1, (double) left / Math.max(1, total))));
            bar.setTitle(Text.color("&d&l" + title(active) + " &7— " + Text.formatTime(Math.max(0, left / 1000))));
        }
        if (active.equals("drop")) dropTick();
        if (active.equals("treasure") && treasure != null)
            treasure.getWorld().spawnParticle(Particle.END_ROD, treasure.clone().add(0.5, 1.5, 0.5), 10, 0.2, 2, 0.2, 0.01);
        if (left <= 0) finish();
    }

    private void bossAbility() {
        List<Player> near = boss.getWorld().getPlayers().stream().filter(p -> p.getLocation().distanceSquared(boss.getLocation()) < 400).toList();
        if (near.isEmpty()) return;
        switch (ThreadLocalRandom.current().nextInt(3)) {
            case 0 -> near.forEach(p -> { p.getWorld().strikeLightningEffect(p.getLocation()); p.damage(4, boss); });
            case 1 -> near.forEach(p -> p.addPotionEffect(new PotionEffect(PotionEffectType.DARKNESS, 80, 0)));
            case 2 -> {
                for (int i = 0; i < 3; i++) boss.getWorld().spawn(boss.getLocation(), WitherSkeleton.class, m -> m.setCustomName(Text.color("&8Слуга Тьмы")));
            }
        }
    }

    private void dropTick() {
        Location c = plugin.spawn().get();
        List<String> loot = cfg("drop").getStringList("loot");
        if (loot.isEmpty()) loot = List.of("DIAMOND", "GOLD_INGOT", "EMERALD", "custom:shadow_shard", "EXPERIENCE_BOTTLE*4");
        ThreadLocalRandom r = ThreadLocalRandom.current();
        for (int i = 0; i < cfg("drop").getInt("items-per-second", 4); i++) {
            String[] g = loot.get(r.nextInt(loot.size())).split("\\*");
            ItemStack it = plugin.items().resolve(g[0]);
            if (it == null) continue;
            it.setAmount(g.length > 1 ? Integer.parseInt(g[1].trim()) : 1);
            Location l = c.clone().add(r.nextDouble(-10, 10), 12, r.nextDouble(-10, 10));
            c.getWorld().dropItemNaturally(l, it);
        }
        Firework fw = c.getWorld().spawn(c.clone().add(r.nextDouble(-8, 8), 2, r.nextDouble(-8, 8)), Firework.class);
        var meta = fw.getFireworkMeta();
        meta.addEffect(FireworkEffect.builder().withColor(Color.PURPLE, Color.FUCHSIA).with(FireworkEffect.Type.BALL_LARGE).build());
        meta.setPower(1);
        fw.setFireworkMeta(meta);
    }

    public void finish() {
        if (active == null) return;
        String type = active;
        switch (type) {
            case "chat", "math" -> Bukkit.broadcastMessage(Text.color(Msg.prefix() + "&7Никто не успел! Ответ: &f" + answer));
            case "hunt", "boss" -> {
                List<Map.Entry<UUID, Double>> top = new ArrayList<>(score.entrySet());
                top.sort((a, b) -> Double.compare(b.getValue(), a.getValue()));
                if (top.isEmpty()) Bukkit.broadcastMessage(Text.color(Msg.prefix() + "&7Ивент завершён — участников нет."));
                Bukkit.broadcastMessage(Text.color("&5&l⚑ Итоги ивента «" + title(type) + "»:"));
                for (int i = 0; i < Math.min(3, top.size()); i++) {
                    Player p = Bukkit.getPlayer(top.get(i).getKey());
                    String name = p != null ? p.getName() : Bukkit.getOfflinePlayer(top.get(i).getKey()).getName();
                    Bukkit.broadcastMessage(Text.color("  &d" + (i + 1) + ". &f" + name + " &8— &7" + Text.formatNumber(Math.round(top.get(i).getValue()))));
                    if (p != null) reward(p, type, i + 1);
                }
                if (boss != null && boss.isValid()) boss.remove();
            }
            case "treasure" -> {
                if (treasure != null && treasure.getBlock().getType() == Material.CHEST) {
                    ((Chest) treasure.getBlock().getState()).getBlockInventory().clear();
                    treasure.getBlock().setType(Material.AIR);
                    Bukkit.broadcastMessage(Text.color(Msg.prefix() + "&7Сокровища никто не нашёл и они исчезли..."));
                }
            }
            default -> Bukkit.broadcastMessage(Text.color(Msg.prefix() + "&7Ивент &f" + title(type) + " &7завершён!"));
        }
        stop();
    }

    public void stop() {
        if (timer != null) timer.cancel();
        if (bar != null) bar.removeAll();
        if (boss != null && boss.isValid()) boss.remove();
        boss = null;
        treasure = null;
        active = null;
        answer = null;
        endAt = 0;
    }

    private void win(Player p) {
        String type = active;
        Bukkit.broadcastMessage(Text.color(Msg.prefix() + "&f" + p.getName() + " &aпобедил в ивенте «" + title(type) + "»!"));
        reward(p, type, 1);
        p.playSound(p.getLocation(), Sound.UI_TOAST_CHALLENGE_COMPLETE, 1f, 1f);
        stop();
    }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onChat(AsyncPlayerChatEvent e) {
        String ans = answer;
        if (ans == null || active == null || !(active.equals("chat") || active.equals("math"))) return;
        if (!plugin.auth().isLoggedIn(e.getPlayer())) return;
        if (e.getMessage().trim().equals(ans)) {
            Player p = e.getPlayer();
            Bukkit.getScheduler().runTask(plugin, () -> { if (ans.equals(answer)) win(p); });
        }
    }

    @EventHandler
    public void onKill(EntityDeathEvent e) {
        Player k = e.getEntity().getKiller();
        if (e.getEntity().getPersistentDataContainer().has(Keys.BOSS, PersistentDataType.BYTE)) {
            e.getDrops().clear();
            e.getDrops().add(plugin.items().resolve("custom:shadow_shard") == null ? new ItemStack(Material.NETHER_STAR) : withAmount(plugin.items().resolve("custom:shadow_shard"), 8));
            e.getDrops().add(new ItemStack(Material.NETHER_STAR));
            e.setDroppedExp(500);
            if ("boss".equals(active)) {
                Bukkit.broadcastMessage(Text.color(Msg.prefix() + "&5Тёмный Повелитель повержен" + (k != null ? " игроком &f" + k.getName() : "") + "&5!"));
                boss = null;
                Bukkit.getScheduler().runTask(plugin, this::finish);
            }
            return;
        }
        if ("hunt".equals(active) && k != null && e.getEntity() instanceof Monster) {
            double v = score.merge(k.getUniqueId(), 1.0, Double::sum);
            plugin.board().actionBar(k, "&d⚔ Охота: &f" + (int) v + " &7убийств");
        }
    }

    private ItemStack withAmount(ItemStack it, int a) {
        it.setAmount(a);
        return it;
    }

    @EventHandler(priority = EventPriority.MONITOR, ignoreCancelled = true)
    public void onBossDamage(EntityDamageByEntityEvent e) {
        if (!e.getEntity().getPersistentDataContainer().has(Keys.BOSS, PersistentDataType.BYTE)) return;
        Player p = e.getDamager() instanceof Player pl ? pl
                : e.getDamager() instanceof Projectile pr && pr.getShooter() instanceof Player pl2 ? pl2 : null;
        if (p != null) score.merge(p.getUniqueId(), e.getFinalDamage(), Double::sum);
    }

    @EventHandler(ignoreCancelled = true)
    public void onOpen(InventoryOpenEvent e) {
        if (!"treasure".equals(active) || treasure == null || !(e.getPlayer() instanceof Player p)) return;
        if (e.getInventory().getLocation() != null && e.getInventory().getLocation().getBlock().getLocation().equals(treasure)) {
            treasure = null;
            win(p);
        }
    }

    // ====================== /event ======================
    @Override
    public boolean onCommand(CommandSender s, Command cmd, String label, String[] a) {
        if (a.length == 0 || !s.hasPermission("shadowsmp.event.admin")) {
            Msg.send(s, "&7Текущий ивент: " + status());
            if (s.hasPermission("shadowsmp.event.admin")) Msg.send(s, "&7/event start <" + String.join("|", TYPES) + "> &8| &7/event stop &8| &7/event setboss");
            else Msg.send(s, "&7Ивенты запускаются автоматически каждые &f" + plugin.getConfig().getLong("events.auto-interval-minutes", 30) + " мин&7.");
            return true;
        }
        switch (a[0].toLowerCase()) {
            case "start" -> {
                if (a.length < 2) { Msg.send(s, "&c/event start <тип>"); return true; }
                if (!start(a[1].toLowerCase())) Msg.send(s, "&cНельзя запустить (уже идёт ивент или неверный тип).");
            }
            case "stop" -> { finish(); Msg.send(s, "&aИвент остановлен."); }
            case "setboss" -> {
                if (!(s instanceof Player p)) return true;
                plugin.getConfig().set("events.types.boss.location", p.getLocation());
                plugin.saveConfig();
                Msg.send(s, "&aМесто появления босса сохранено.");
            }
            default -> Msg.send(s, "&c/event start|stop|setboss");
        }
        return true;
    }

    @Override
    public List<String> onTabComplete(CommandSender s, Command c, String l, String[] a) {
        if (!s.hasPermission("shadowsmp.event.admin")) return List.of();
        if (a.length == 1) return filter(List.of("start", "stop", "setboss"), a[0]);
        if (a.length == 2 && a[0].equalsIgnoreCase("start")) return filter(TYPES, a[1]);
        return List.of();
    }

    private static List<String> filter(List<String> l, String p) {
        return l.stream().filter(x -> x.startsWith(p.toLowerCase())).toList();
    }
}
