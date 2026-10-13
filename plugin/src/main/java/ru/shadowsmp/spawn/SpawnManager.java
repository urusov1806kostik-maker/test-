package ru.shadowsmp.spawn;

import org.bukkit.*;
import org.bukkit.block.Block;
import org.bukkit.block.data.BlockData;
import org.bukkit.block.data.type.Lantern;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.*;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockPlaceEvent;
import org.bukkit.event.entity.*;
import org.bukkit.event.player.*;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.util.Transformation;
import org.joml.AxisAngle4f;
import org.joml.Vector3f;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Keys;
import ru.shadowsmp.util.Msg;
import ru.shadowsmp.util.Text;

import java.io.File;
import java.io.IOException;
import java.util.List;

/** Спавн: /spawn, /setspawn, защита, генерация красивого спавна, голограммы. */
public class SpawnManager implements Listener {
    private final ShadowSMP plugin;
    private final File file;
    private Location spawn;

    public SpawnManager(ShadowSMP plugin) {
        this.plugin = plugin;
        this.file = new File(plugin.getDataFolder(), "data/spawn.yml");
        YamlConfiguration y = YamlConfiguration.loadConfiguration(file);
        if (y.contains("spawn")) spawn = y.getLocation("spawn");
    }

    public Location get() {
        if (spawn == null || spawn.getWorld() == null) return Bukkit.getWorlds().get(0).getSpawnLocation().add(0.5, 0, 0.5);
        return spawn;
    }

    public void set(Location l) {
        spawn = l.clone();
        l.getWorld().setSpawnLocation(l);
        YamlConfiguration y = new YamlConfiguration();
        y.set("spawn", spawn);
        try {
            file.getParentFile().mkdirs();
            y.save(file);
        } catch (IOException ignored) {}
    }

    public void teleport(Player p) {
        p.teleport(get());
        p.playSound(p.getLocation(), Sound.ENTITY_ENDERMAN_TELEPORT, 1f, 1f);
    }

    public boolean inSpawn(Location l) {
        Location s = get();
        int r = plugin.getConfig().getInt("spawn.protection-radius", 40);
        return r > 0 && l.getWorld() == s.getWorld()
                && Math.abs(l.getX() - s.getX()) <= r && Math.abs(l.getZ() - s.getZ()) <= r;
    }

    private boolean bypass(Player p) {
        return p.hasPermission("shadowsmp.spawn.bypass") && p.getGameMode() == GameMode.CREATIVE;
    }

    // ====================== Защита ======================
    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onBreak(BlockBreakEvent e) {
        if (inSpawn(e.getBlock().getLocation()) && !bypass(e.getPlayer())) e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onPlace(BlockPlaceEvent e) {
        if (inSpawn(e.getBlock().getLocation()) && !bypass(e.getPlayer())) e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onBucket(PlayerBucketEmptyEvent e) {
        if (inSpawn(e.getBlock().getLocation()) && !bypass(e.getPlayer())) e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onDamage(EntityDamageEvent e) {
        if (!(e.getEntity() instanceof Player p) || !inSpawn(p.getLocation())) return;
        if (e.getCause() == EntityDamageEvent.DamageCause.VOID) {
            e.setCancelled(true);
            Bukkit.getScheduler().runTask(plugin, () -> teleport(p));
            return;
        }
        if (e.getCause() != EntityDamageEvent.DamageCause.KILL) e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onHunger(FoodLevelChangeEvent e) {
        if (e.getEntity() instanceof Player p && inSpawn(p.getLocation()) && e.getFoodLevel() < p.getFoodLevel()) e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onMobSpawn(CreatureSpawnEvent e) {
        if (e.getSpawnReason() == CreatureSpawnEvent.SpawnReason.NATURAL && e.getEntity() instanceof Monster && inSpawn(e.getLocation()))
            e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onExplode(EntityExplodeEvent e) {
        e.blockList().removeIf(b -> inSpawn(b.getLocation()));
    }

    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onInteract(PlayerInteractEvent e) {
        if (e.getClickedBlock() == null || bypass(e.getPlayer()) || !inSpawn(e.getClickedBlock().getLocation())) return;
        Material t = e.getClickedBlock().getType();
        if (t.name().contains("CHEST") || t.name().contains("SHULKER") || t == Material.BARREL || t == Material.HOPPER
                || t.name().contains("FURNACE") || t == Material.FLOWER_POT || t.name().contains("SIGN")
                || t == Material.ITEM_FRAME || t.name().endsWith("_BED"))
            e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.LOW, ignoreCancelled = true)
    public void onHangingBreak(org.bukkit.event.hanging.HangingBreakByEntityEvent e) {
        if (inSpawn(e.getEntity().getLocation()) && !(e.getRemover() instanceof Player p && bypass(p))) e.setCancelled(true);
    }

    @EventHandler
    public void onFirstJoin(PlayerJoinEvent e) {
        if (!e.getPlayer().hasPlayedBefore() || plugin.getConfig().getBoolean("spawn.teleport-on-join", true))
            Bukkit.getScheduler().runTask(plugin, () -> e.getPlayer().teleport(get()));
    }

    @EventHandler
    public void onRespawn(PlayerRespawnEvent e) {
        if (!e.isBedSpawn() && !e.isAnchorSpawn()) e.setRespawnLocation(get());
    }

    @EventHandler
    public void onVoid(PlayerMoveEvent e) {
        if (e.getTo() != null && e.getTo().getY() < e.getTo().getWorld().getMinHeight() - 10 && inSpawn(e.getTo())) teleport(e.getPlayer());
    }

    // ====================== Генератор спавна ======================
    public void build(org.bukkit.command.CommandSender p, Location at) {
        Location base = at.getBlock().getLocation();
        World w = base.getWorld();
        int cx = base.getBlockX(), cy = base.getBlockY() - 1, cz = base.getBlockZ();
        int R = 20;
        Msg.send(p, "&7Строю спавн ShadowSMP...");
        // Удаляем старые голограммы спавна рядом
        for (Entity en : w.getNearbyEntities(base, 40, 30, 40))
            if (en.getPersistentDataContainer().has(Keys.SPAWN_DECOR, PersistentDataType.BYTE)) en.remove();

        for (int x = -R - 3; x <= R + 3; x++) for (int z = -R - 3; z <= R + 3; z++) {
            double d = Math.sqrt(x * x + z * z);
            if (d > R + 2.5) continue;
            // очистка воздуха над площадкой
            for (int y = 1; y <= 18; y++) set(w, cx + x, cy + y, cz + z, Material.AIR);
            // фундамент
            for (int y = -1; y >= -6; y--) {
                Block b = w.getBlockAt(cx + x, cy + y, cz + z);
                if (b.getType().isSolid() && y < -2) break;
                b.setType(d > R + 1 ? Material.COBBLED_DEEPSLATE : Material.DEEPSLATE_TILES, false);
            }
            set(w, cx + x, cy, cz + z, floor(x, z, d, R));
        }
        // фонтан в центре
        for (int x = -5; x <= 5; x++) for (int z = -5; z <= 5; z++) {
            double d = Math.sqrt(x * x + z * z);
            if (d <= 3.6) {
                set(w, cx + x, cy - 1, cz + z, Material.SEA_LANTERN);
                set(w, cx + x, cy, cz + z, Material.WATER);
            } else if (d <= 4.6) {
                set(w, cx + x, cy, cz + z, Material.POLISHED_BLACKSTONE_BRICKS);
                set(w, cx + x, cy + 1, cz + z, Material.POLISHED_BLACKSTONE_BRICK_SLAB);
            }
        }
        // центральный обелиск
        set(w, cx, cy, cz, Material.CRYING_OBSIDIAN);
        for (int y = 1; y <= 4; y++) set(w, cx, cy + y, cz, y == 4 ? Material.AMETHYST_BLOCK : Material.CRYING_OBSIDIAN);
        set(w, cx, cy + 5, cz, Material.END_ROD);
        for (int[] o : new int[][]{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
            set(w, cx + o[0], cy + 1, cz + o[1], Material.OBSIDIAN);
            set(w, cx + o[0], cy + 2, cz + o[1], Material.AMETHYST_CLUSTER);
        }
        // колонны по кругу
        for (int i = 0; i < 12; i++) {
            double a = Math.PI * 2 * i / 12 + Math.PI / 12;
            int px = (int) Math.round(Math.cos(a) * (R - 1)), pz = (int) Math.round(Math.sin(a) * (R - 1));
            for (int y = 1; y <= 6; y++) {
                Material m = y == 1 ? Material.CHISELED_POLISHED_BLACKSTONE : y == 6 ? Material.CHISELED_POLISHED_BLACKSTONE
                        : y == 3 ? Material.GILDED_BLACKSTONE : Material.POLISHED_BLACKSTONE_BRICKS;
                set(w, cx + px, cy + y, cz + pz, m);
            }
            set(w, cx + px, cy + 7, cz + pz, Material.AMETHYST_BLOCK);
            Block lantern = w.getBlockAt(cx + px, cy + 8, cz + pz);
            lantern.setType(Material.SOUL_LANTERN, false);
        }
        // низкая стена по краю с проходами
        for (int x = -R - 1; x <= R + 1; x++) for (int z = -R - 1; z <= R + 1; z++) {
            double d = Math.sqrt(x * x + z * z);
            if (d < R + 0.5 || d > R + 1.5) continue;
            if (Math.abs(x) <= 2 || Math.abs(z) <= 2) continue; // проходы
            set(w, cx + x, cy + 1, cz + z, Material.POLISHED_BLACKSTONE_BRICKS);
            set(w, cx + x, cy + 2, cz + z, Material.POLISHED_BLACKSTONE_BRICK_SLAB);
        }
        // фонари вдоль дорожек
        for (int[] dir : new int[][]{{1, 0}, {-1, 0}, {0, 1}, {0, -1}}) {
            for (int dist = 8; dist <= R - 3; dist += 5) {
                for (int side : new int[]{-3, 3}) {
                    int lx = dir[0] * dist + (dir[0] == 0 ? side : 0), lz = dir[1] * dist + (dir[1] == 0 ? side : 0);
                    set(w, cx + lx, cy + 1, cz + lz, Material.POLISHED_BLACKSTONE_WALL);
                    set(w, cx + lx, cy + 2, cz + lz, Material.POLISHED_BLACKSTONE_WALL);
                    Block l = w.getBlockAt(cx + lx, cy + 3, cz + lz);
                    l.setType(Material.LANTERN, false);
                    BlockData bd = l.getBlockData();
                    if (bd instanceof Lantern lan) { lan.setHanging(false); l.setBlockData(lan, false); }
                }
            }
        }
        // голограммы
        Location holo = new Location(w, cx + 0.5, cy + 8.5, cz + 0.5);
        hologram(holo, "<g:#7B2FF7:#F107A3>&l✦ ShadowSMP ✦</g>", 3f);
        hologram(holo.clone().add(0, -1.1, 0), "&7Добро пожаловать на сервер!", 1.4f);
        hologram(holo.clone().add(0, -1.7, 0), "&d/menu &8• &d/crafts &8• &d/shop &8• &d/event", 1.2f);

        Location sp = new Location(w, cx + 0.5, cy + 1, cz + 7.5, 180f, 0f);
        set(sp);
        plugin.npcs().createSpawnDefaults(new Location(w, cx + 0.5, cy + 1, cz + 0.5));
        Msg.send(p, "&aСпавн построен и установлен!");
    }

    private Material floor(int x, int z, double d, int R) {
        boolean path = Math.abs(x) <= 1 || Math.abs(z) <= 1;
        if (d > R) return Material.POLISHED_DEEPSLATE;
        if (path && d > 5) return (Math.abs(x) + Math.abs(z)) % 2 == 0 ? Material.POLISHED_BLACKSTONE : Material.POLISHED_DEEPSLATE;
        double ang = Math.toDegrees(Math.atan2(z, x));
        if (d > 6 && Math.abs(((ang + 360) % 45) - 22.5) < 3.2) return Material.AMETHYST_BLOCK; // лучи
        if (Math.abs(d - 7) < 0.5 || Math.abs(d - 14) < 0.5) return Material.CHISELED_POLISHED_BLACKSTONE;
        if (Math.abs(d - 10.5) < 0.5) return Material.PURPUR_BLOCK;
        if (Math.abs(d - 17.5) < 0.5) return Material.CRYING_OBSIDIAN;
        if ((x * 7 + z * 13) % 11 == 0) return Material.GILDED_BLACKSTONE;
        return (x + z) % 2 == 0 ? Material.POLISHED_BLACKSTONE_BRICKS : Material.DEEPSLATE_TILES;
    }

    private void set(World w, int x, int y, int z, Material m) {
        w.getBlockAt(x, y, z).setType(m, false);
    }

    public TextDisplay hologram(Location l, String text, float scale) {
        return l.getWorld().spawn(l, TextDisplay.class, t -> {
            t.setText(Text.color(text));
            t.setBillboard(Display.Billboard.CENTER);
            t.setShadowed(true);
            t.setDefaultBackground(false);
            t.setBackgroundColor(Color.fromARGB(0, 0, 0, 0));
            t.setTransformation(new Transformation(new Vector3f(), new AxisAngle4f(), new Vector3f(scale, scale, scale), new AxisAngle4f()));
            t.getPersistentDataContainer().set(Keys.SPAWN_DECOR, PersistentDataType.BYTE, (byte) 1);
            t.getPersistentDataContainer().set(Keys.HOLOGRAM, PersistentDataType.BYTE, (byte) 1);
        });
    }

    public void removeHolograms(Location near, double r) {
        for (Entity en : near.getWorld().getNearbyEntities(near, r, r, r))
            if (en instanceof TextDisplay && en.getPersistentDataContainer().has(Keys.HOLOGRAM, PersistentDataType.BYTE)) en.remove();
    }

    public List<String> info() {
        Location s = get();
        return List.of(s.getWorld().getName(), String.valueOf(s.getBlockX()), String.valueOf(s.getBlockY()), String.valueOf(s.getBlockZ()));
    }
}
