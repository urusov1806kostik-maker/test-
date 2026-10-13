package ru.shadowsmp.npc;

import org.bukkit.*;
import org.bukkit.command.*;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.*;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.EntityDamageEvent;
import org.bukkit.event.player.PlayerInteractEntityEvent;
import org.bukkit.event.world.EntitiesLoadEvent;
import org.bukkit.inventory.EquipmentSlot;
import org.bukkit.inventory.ItemStack;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.profile.PlayerProfile;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Actions;
import ru.shadowsmp.util.Keys;
import ru.shadowsmp.util.Msg;
import ru.shadowsmp.util.Text;

import java.io.File;
import java.io.IOException;
import java.util.*;

/** Кастомные NPC на сущности Mannequin (скин игрока) или любом мобе. Клик выполняет действия. */
public class NpcManager implements Listener, CommandExecutor, TabCompleter {
    private final ShadowSMP plugin;
    private final File file;
    private YamlConfiguration data;
    private final Map<String, Entity> spawned = new HashMap<>();
    private final Map<String, PlayerProfile> skins = new HashMap<>();
    private final Map<UUID, Long> cooldown = new HashMap<>();

    public NpcManager(ShadowSMP plugin) {
        this.plugin = plugin;
        this.file = new File(plugin.getDataFolder(), "npcs.yml");
        this.data = YamlConfiguration.loadConfiguration(file);
        Bukkit.getScheduler().runTaskTimer(plugin, this::ensureSpawned, 40, 100);
        Bukkit.getScheduler().runTaskTimer(plugin, this::lookAtPlayers, 40, 4);
    }

    public void reload() {
        despawnAll();
        data = YamlConfiguration.loadConfiguration(file);
        ensureSpawned();
    }

    private void save() {
        try { data.save(file); } catch (IOException e) { plugin.getLogger().warning("npcs.yml: " + e.getMessage()); }
    }

    private ConfigurationSection sec(String id) {
        return data.getConfigurationSection("npcs." + id);
    }

    public Set<String> ids() {
        ConfigurationSection s = data.getConfigurationSection("npcs");
        return s == null ? Set.of() : s.getKeys(false);
    }

    public void despawnAll() {
        spawned.values().forEach(Entity::remove);
        spawned.clear();
    }

    public void despawn(String id) {
        Entity e = spawned.remove(id);
        if (e != null) e.remove();
    }

    private void ensureSpawned() {
        for (String id : ids()) {
            Entity e = spawned.get(id);
            if (e != null && e.isValid()) continue;
            Location l = sec(id).getLocation("location");
            if (l == null || l.getWorld() == null || !l.getWorld().isChunkLoaded(l.getBlockX() >> 4, l.getBlockZ() >> 4)) continue;
            spawn(id);
        }
    }

    private void spawn(String id) {
        despawn(id);
        ConfigurationSection c = sec(id);
        Location l = c.getLocation("location");
        EntityType type;
        try { type = EntityType.valueOf(c.getString("type", "MANNEQUIN").toUpperCase()); } catch (Exception ex) { type = EntityType.MANNEQUIN; }
        if (type.getEntityClass() == null || !LivingEntity.class.isAssignableFrom(type.getEntityClass())) type = EntityType.MANNEQUIN;
        Entity en = l.getWorld().spawnEntity(l, type);
        en.setPersistent(false);
        en.setInvulnerable(true);
        en.setSilent(true);
        en.setGravity(false);
        en.setCustomName(Text.color(c.getString("name", id)));
        en.setCustomNameVisible(true);
        en.getPersistentDataContainer().set(Keys.NPC_ID, PersistentDataType.STRING, id);
        if (en instanceof LivingEntity le) {
            le.setAI(false);
            le.setCollidable(false);
            le.setRemoveWhenFarAway(false);
            ItemStack hand = c.getItemStack("hand");
            if (hand != null && le.getEquipment() != null) le.getEquipment().setItem(EquipmentSlot.HAND, hand);
        }
        if (en instanceof Mannequin m) {
            m.setImmovable(true);
            String desc = c.getString("description", "");
            if (desc.isBlank()) m.setHideDescription(true);
            else { m.setHideDescription(false); m.setDescription(Text.color(desc)); }
            String skin = c.getString("skin", "");
            if (!skin.isBlank()) applySkin(m, skin);
        }
        if (en instanceof Villager v) v.setProfession(Villager.Profession.NITWIT);
        spawned.put(id, en);
    }

    private void applySkin(Mannequin m, String name) {
        PlayerProfile cached = skins.get(name.toLowerCase());
        if (cached != null) { m.setPlayerProfile(cached); return; }
        try {
            Bukkit.createPlayerProfile(name).update().thenAccept(prof -> Bukkit.getScheduler().runTask(plugin, () -> {
                skins.put(name.toLowerCase(), prof);
                if (m.isValid()) m.setPlayerProfile(prof);
            }));
        } catch (Exception ex) {
            plugin.getLogger().warning("Скин " + name + ": " + ex.getMessage());
        }
    }

    private void lookAtPlayers() {
        for (Map.Entry<String, Entity> en : spawned.entrySet()) {
            Entity e = en.getValue();
            if (!e.isValid() || !sec(en.getKey()).getBoolean("look", true)) continue;
            Player near = null;
            double best = 64;
            for (Player p : e.getWorld().getPlayers()) {
                double d = p.getLocation().distanceSquared(e.getLocation());
                if (d < best) { best = d; near = p; }
            }
            if (near == null) continue;
            Location eye = e instanceof LivingEntity le ? le.getEyeLocation() : e.getLocation();
            org.bukkit.util.Vector dir = near.getEyeLocation().toVector().subtract(eye.toVector());
            Location look = e.getLocation().setDirection(dir);
            e.setRotation(look.getYaw(), look.getPitch());
        }
    }

    @EventHandler
    public void onLoad(EntitiesLoadEvent e) {
        // удаляем «осиротевшие» NPC (например после краша)
        for (Entity en : e.getEntities()) {
            String id = en.getPersistentDataContainer().get(Keys.NPC_ID, PersistentDataType.STRING);
            if (id != null && spawned.get(id) != en) en.remove();
        }
    }

    private String npcOf(Entity e) {
        return e.getPersistentDataContainer().get(Keys.NPC_ID, PersistentDataType.STRING);
    }

    @EventHandler(priority = EventPriority.HIGH)
    public void onClick(PlayerInteractEntityEvent e) {
        String id = npcOf(e.getRightClicked());
        if (id == null) return;
        e.setCancelled(true);
        if (e.getHand() == EquipmentSlot.HAND) click(e.getPlayer(), id);
    }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onHit(EntityDamageByEntityEvent e) {
        String id = npcOf(e.getEntity());
        if (id == null) return;
        e.setCancelled(true);
        if (e.getDamager() instanceof Player p) click(p, id);
    }

    @EventHandler(priority = EventPriority.LOWEST)
    public void onDamage(EntityDamageEvent e) {
        if (npcOf(e.getEntity()) != null) e.setCancelled(true);
    }

    private void click(Player p, String id) {
        long now = System.currentTimeMillis();
        if (now - cooldown.getOrDefault(p.getUniqueId(), 0L) < 600) return;
        cooldown.put(p.getUniqueId(), now);
        if (!plugin.auth().isLoggedIn(p)) return;
        List<String> actions = sec(id).getStringList("actions");
        if (actions.isEmpty()) Msg.send(p, "&7Этот NPC пока ничего не умеет.");
        else Actions.run(p, actions, new String[0]);
    }

    public void create(String id, Location l, String type, String name) {
        ConfigurationSection c = data.createSection("npcs." + id);
        c.set("type", type.toUpperCase());
        c.set("name", name);
        c.set("location", l);
        c.set("look", true);
        c.set("skin", "");
        c.set("description", "");
        c.set("actions", new ArrayList<String>());
        save();
        spawn(id);
    }

    /** NPC по умолчанию вокруг спавна. */
    public void createSpawnDefaults(Location center) {
        Object[][] def = {
                {"shop", "&6&lМагазин", "&7Нажми, чтобы открыть", 0, -11, List.of("[menu] shop")},
                {"crafts", "&d&lКастом крафты", "&7Талисманы и оружие", 11, 0, List.of("[menu] crafts")},
                {"events", "&5&lИвенты", "&7Информация об ивентах", -11, 0, List.of("[player] event")},
                {"guide", "&b&lГид", "&7Правила и помощь", 0, 11, List.of("[player] rules", "[sound] ENTITY_VILLAGER_YES")},
                {"rtp", "&a&lСлучайный телепорт", "&7Нажми — и ты в дикой местности", 8, 8, List.of("[player] tpr", "[sound] ENTITY_ENDERMAN_TELEPORT")},
        };
        for (Object[] d : def) {
            String id = (String) d[0];
            Location l = center.clone().add((int) d[3], 0, (int) d[4]);
            l.setDirection(center.toVector().subtract(l.toVector()));
            create(id, l, "MANNEQUIN", (String) d[1]);
            sec(id).set("description", d[2]);
            @SuppressWarnings("unchecked") List<String> acts = (List<String>) d[5];
            sec(id).set("actions", acts);
            save();
            spawn(id);
        }
    }

    // ====================== /npc ======================
    @Override
    public boolean onCommand(CommandSender s, Command cmd, String label, String[] a) {
        if (a.length == 0) { help(s); return true; }
        String sub = a[0].toLowerCase();
        if (sub.equals("list")) {
            Msg.send(s, "&7NPC: &f" + String.join(", ", ids()));
            return true;
        }
        if (a.length < 2) { help(s); return true; }
        String id = a[1].toLowerCase();
        Player p = s instanceof Player pl ? pl : null;
        if (!sub.equals("create") && sec(id) == null) { Msg.send(s, "&cNPC " + id + " не найден."); return true; }
        String rest = a.length > 2 ? String.join(" ", Arrays.copyOfRange(a, 2, a.length)) : "";
        switch (sub) {
            case "create" -> {
                if (p == null) return true;
                if (sec(id) != null) { Msg.send(s, "&cТакой NPC уже есть."); return true; }
                create(id, p.getLocation(), a.length > 2 ? a[2] : "MANNEQUIN", "&f" + id);
                Msg.send(s, "&aNPC &f" + id + " &aсоздан. Настрой: /npc name|skin|desc|action|type");
                return true;
            }
            case "remove" -> { despawn(id); data.set("npcs." + id, null); }
            case "tphere" -> { if (p != null) sec(id).set("location", p.getLocation()); }
            case "tp" -> { if (p != null) p.teleport(sec(id).getLocation("location")); return true; }
            case "name" -> sec(id).set("name", rest);
            case "desc" -> sec(id).set("description", rest);
            case "skin" -> sec(id).set("skin", rest);
            case "type" -> sec(id).set("type", rest.toUpperCase());
            case "look" -> sec(id).set("look", Boolean.parseBoolean(rest));
            case "hand" -> { if (p != null) sec(id).set("hand", p.getInventory().getItemInMainHand().clone()); }
            case "action" -> {
                List<String> acts = new ArrayList<>(sec(id).getStringList("actions"));
                if (a.length >= 3 && a[2].equalsIgnoreCase("clear")) acts.clear();
                else if (a.length >= 4 && a[2].equalsIgnoreCase("add")) acts.add(String.join(" ", Arrays.copyOfRange(a, 3, a.length)));
                else if (a.length >= 3 && a[2].equalsIgnoreCase("list")) {
                    for (int i = 0; i < acts.size(); i++) s.sendMessage(Text.color("&7" + i + ": &f" + acts.get(i)));
                    return true;
                } else { Msg.send(s, "&c/npc action <id> add <действие> | clear | list"); return true; }
                sec(id).set("actions", acts);
            }
            default -> { help(s); return true; }
        }
        save();
        if (sec(id) != null) spawn(id);
        Msg.send(s, "&aГотово.");
        return true;
    }

    private void help(CommandSender s) {
        for (String l : List.of("&5&lNPC:", "&f/npc create <id> [MANNEQUIN|VILLAGER|ZOMBIE...]", "&f/npc remove|tp|tphere <id>",
                "&f/npc name <id> <имя> &7| &f/npc desc <id> <текст>", "&f/npc skin <id> <ник> &7| &f/npc type <id> <тип>",
                "&f/npc look <id> true|false &7| &f/npc hand <id>", "&f/npc action <id> add <действие> &7| clear | list",
                "&7Действия: [player] cmd, [console] cmd, [message] txt, [menu] shop, [sound] X, [delay] 20 ...", "&f/npc list"))
            s.sendMessage(Text.color(l));
    }

    @Override
    public List<String> onTabComplete(CommandSender s, Command c, String l, String[] a) {
        if (a.length == 1) return pref(List.of("create", "remove", "tp", "tphere", "name", "desc", "skin", "type", "look", "hand", "action", "list"), a[0]);
        if (a.length == 2 && !a[0].equalsIgnoreCase("create")) return pref(new ArrayList<>(ids()), a[1]);
        if (a.length == 3 && (a[0].equalsIgnoreCase("type") || a[0].equalsIgnoreCase("create")))
            return pref(Arrays.stream(EntityType.values()).filter(t -> t.getEntityClass() != null && LivingEntity.class.isAssignableFrom(t.getEntityClass())).map(Enum::name).toList(), a[2]);
        if (a.length == 3 && a[0].equalsIgnoreCase("action")) return pref(List.of("add", "clear", "list"), a[2]);
        if (a.length == 4 && a[0].equalsIgnoreCase("action")) return pref(List.of("[player]", "[console]", "[message]", "[broadcast]", "[title]", "[actionbar]", "[sound]", "[delay]", "[menu]", "[give]", "[coins]", "[shadowcoins]", "[effect]", "[spawn]", "[close]"), a[3]);
        if (a.length == 3 && a[0].equalsIgnoreCase("look")) return List.of("true", "false");
        if (a.length == 3 && a[0].equalsIgnoreCase("skin")) return null;
        return List.of();
    }

    private static List<String> pref(List<String> l, String p) {
        return l.stream().filter(x -> x.toLowerCase().startsWith(p.toLowerCase())).toList();
    }
}
