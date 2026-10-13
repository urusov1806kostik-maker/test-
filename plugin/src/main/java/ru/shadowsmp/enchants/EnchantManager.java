package ru.shadowsmp.enchants;

import org.bukkit.*;
import org.bukkit.block.Block;
import org.bukkit.block.BlockFace;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.entity.*;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.block.BlockBreakEvent;
import org.bukkit.event.block.BlockDropItemEvent;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.EntityDeathEvent;
import org.bukkit.event.entity.PlayerDeathEvent;
import org.bukkit.event.inventory.PrepareAnvilEvent;
import org.bukkit.inventory.*;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.inventory.meta.SkullMeta;
import org.bukkit.inventory.view.AnvilView;
import org.bukkit.persistence.PersistentDataContainer;
import org.bukkit.persistence.PersistentDataType;
import org.bukkit.potion.PotionEffect;
import org.bukkit.potion.PotionEffectType;
import org.bukkit.util.RayTraceResult;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.Keys;
import ru.shadowsmp.util.Text;

import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

/** Кастомные зачарования + книги + применение через наковальню. */
public class EnchantManager implements Listener {
    private static final String[] ROMAN = {"", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"};
    private final ShadowSMP plugin;
    private final Map<String, CustomEnchant> enchants = new LinkedHashMap<>();
    private final Set<Location> drilling = new HashSet<>();

    public EnchantManager(ShadowSMP plugin) {
        this.plugin = plugin;
        reload();
    }

    public void reload() {
        enchants.clear();
        // встроенные зачарования; названия/уровни можно поменять в config.yml -> enchants
        def("vampirism", "&4Вампиризм", 3, CustomEnchant.Target.WEAPON, "Шанс восстановить здоровье при ударе");
        def("wither", "&8Иссушение", 3, CustomEnchant.Target.WEAPON, "Шанс наложить иссушение");
        def("venom", "&2Яд", 3, CustomEnchant.Target.WEAPON, "Шанс отравить цель");
        def("frost", "&bЗаморозка", 3, CustomEnchant.Target.WEAPON, "Шанс замедлить и заморозить цель");
        def("thunder", "&eГромовержец", 3, CustomEnchant.Target.WEAPON, "Шанс ударить молнией");
        def("beheading", "&cОбезглавливание", 3, CustomEnchant.Target.WEAPON, "Шанс выбить голову игрока");
        def("drill", "&6Бур", 1, CustomEnchant.Target.PICKAXE, "Копает 3x3");
        def("autosmelt", "&6Автоплавка", 1, CustomEnchant.Target.TOOL, "Сразу переплавляет руду");
        def("telepathy", "&dТелепатия", 1, CustomEnchant.Target.TOOL, "Дроп сразу в инвентарь");
        def("wisdom", "&aМудрость", 3, CustomEnchant.Target.WEAPON, "Больше опыта с мобов");
        def("reflect", "&5Отражение", 3, CustomEnchant.Target.ARMOR, "Отражает часть урона");
        def("evasion", "&7Уклонение", 3, CustomEnchant.Target.ARMOR, "Шанс увернуться от удара");
        def("swiftness", "&fВетер", 2, CustomEnchant.Target.BOOTS, "Постоянная скорость");
        def("owl", "&9Ночное зрение", 1, CustomEnchant.Target.HELMET, "Постоянное ночное зрение");
        def("vitality", "&cЖивучесть", 3, CustomEnchant.Target.ARMOR, "Регенерация при низком здоровье");
    }

    private void def(String id, String name, int max, CustomEnchant.Target t, String desc) {
        ConfigurationSection c = plugin.getConfig().getConfigurationSection("enchants." + id);
        if (c != null && !c.getBoolean("enabled", true)) return;
        enchants.put(id, new CustomEnchant(id,
                c != null ? c.getString("name", name) : name,
                c != null ? c.getInt("max-level", max) : max, t,
                c != null ? c.getString("description", desc) : desc));
    }

    public Collection<CustomEnchant> all() { return enchants.values(); }

    public Set<String> ids() { return enchants.keySet(); }

    public CustomEnchant get(String id) { return enchants.get(id.toLowerCase()); }

    private NamespacedKey key(String id) { return Keys.of("ench_" + id); }

    public int level(ItemStack it, String id) {
        if (it == null || !it.hasItemMeta()) return 0;
        Integer v = it.getItemMeta().getPersistentDataContainer().get(key(id), PersistentDataType.INTEGER);
        return v == null ? 0 : v;
    }

    public Map<String, Integer> levels(ItemStack it) {
        Map<String, Integer> m = new LinkedHashMap<>();
        if (it == null || !it.hasItemMeta()) return m;
        for (String id : enchants.keySet()) {
            int l = level(it, id);
            if (l > 0) m.put(id, l);
        }
        return m;
    }

    /** Ставит зачарование и перерисовывает строки описания. */
    public void apply(ItemStack it, String id, int lvl) {
        CustomEnchant ce = get(id);
        if (ce == null || it == null) return;
        ItemMeta m = it.getItemMeta();
        PersistentDataContainer pdc = m.getPersistentDataContainer();
        if (lvl <= 0) pdc.remove(key(id)); else pdc.set(key(id), PersistentDataType.INTEGER, lvl);
        it.setItemMeta(m);
        redrawLore(it);
    }

    private void redrawLore(ItemStack it) {
        ItemMeta m = it.getItemMeta();
        PersistentDataContainer pdc = m.getPersistentDataContainer();
        int old = pdc.getOrDefault(Keys.ENCH_LINES, PersistentDataType.INTEGER, 0);
        List<String> lore = m.hasLore() ? new ArrayList<>(m.getLore()) : new ArrayList<>();
        for (int i = 0; i < old && !lore.isEmpty(); i++) lore.remove(0);
        List<String> lines = new ArrayList<>();
        for (Map.Entry<String, Integer> e : levels(it).entrySet()) {
            lines.add(Text.color("&7" + enchants.get(e.getKey()).name() + " " + roman(e.getValue())));
        }
        lore.addAll(0, lines);
        pdc.set(Keys.ENCH_LINES, PersistentDataType.INTEGER, lines.size());
        m.setLore(lore);
        if (!lines.isEmpty() && !m.hasEnchants()) m.setEnchantmentGlintOverride(true);
        it.setItemMeta(m);
    }

    public static String roman(int n) {
        return n >= 0 && n < ROMAN.length ? ROMAN[n] : String.valueOf(n);
    }

    public ItemStack book(String id, int lvl) {
        CustomEnchant ce = get(id);
        if (ce == null) return null;
        ItemStack b = new ItemStack(Material.ENCHANTED_BOOK);
        ItemMeta m = b.getItemMeta();
        m.setDisplayName(Text.color("&5&lКнига: &r" + ce.name() + " " + roman(lvl)));
        m.setLore(Text.color(List.of("&7" + ce.description(), "&8Для: " + ce.target().ru(), "",
                "&eПоложи в наковальню вместе с предметом")));
        m.setItemModel(NamespacedKey.fromString("shadowsmp:enchant_book"));
        m.getPersistentDataContainer().set(Keys.ITEM_ID, PersistentDataType.STRING, "book:" + id);
        m.getPersistentDataContainer().set(key(id), PersistentDataType.INTEGER, lvl);
        m.setMaxStackSize(1);
        b.setItemMeta(m);
        return b;
    }

    // ====================== Наковальня ======================
    @EventHandler(priority = EventPriority.HIGH)
    public void onAnvil(PrepareAnvilEvent e) {
        AnvilView view = e.getView();
        ItemStack left = e.getInventory().getItem(0), right = e.getInventory().getItem(1);
        if (left == null || right == null || right.getType() != Material.ENCHANTED_BOOK) return;
        Map<String, Integer> bookLevels = levels(right);
        if (bookLevels.isEmpty()) return;
        ItemStack result = left.clone();
        int cost = 0;
        boolean changed = false;
        for (Map.Entry<String, Integer> b : bookLevels.entrySet()) {
            CustomEnchant ce = enchants.get(b.getKey());
            if (!ce.target().fits(left.getType()) && left.getType() != Material.ENCHANTED_BOOK) continue;
            int cur = level(result, ce.id());
            int nl = cur == b.getValue() ? Math.min(cur + 1, ce.maxLevel()) : Math.max(cur, b.getValue());
            if (nl == cur) continue;
            apply(result, ce.id(), nl);
            cost += 4 * nl;
            changed = true;
        }
        if (!changed) { e.setResult(null); return; }
        String rename = view.getRenameText();
        if (rename != null && !rename.isBlank()) {
            ItemMeta m = result.getItemMeta();
            m.setDisplayName(rename);
            result.setItemMeta(m);
        }
        e.setResult(result);
        int finalCost = Math.max(1, cost);
        Bukkit.getScheduler().runTask(plugin, () -> { view.setMaximumRepairCost(100); view.setRepairCost(finalCost); });
        view.setMaximumRepairCost(100);
        view.setRepairCost(finalCost);
    }

    // ====================== Бой ======================
    @EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
    public void onHit(EntityDamageByEntityEvent e) {
        if (!(e.getEntity() instanceof LivingEntity victim)) return;
        ThreadLocalRandom r = ThreadLocalRandom.current();
        if (victim instanceof Player vp) {
            int evasion = 0, reflect = 0;
            for (ItemStack a : vp.getInventory().getArmorContents()) {
                evasion += level(a, "evasion");
                reflect += level(a, "reflect");
            }
            if (evasion > 0 && r.nextDouble(100) < evasion * 3) {
                e.setCancelled(true);
                plugin.board().actionBar(vp, "&7&l↷ Уклонение!");
                return;
            }
            if (reflect > 0 && e.getDamager() instanceof LivingEntity att) {
                double dmg = e.getDamage() * reflect * 0.05;
                Bukkit.getScheduler().runTask(plugin, () -> { if (!att.isDead()) att.damage(dmg); });
            }
        }
        if (!(e.getDamager() instanceof Player p)) return;
        ItemStack w = p.getInventory().getItemInMainHand();
        int l;
        if ((l = level(w, "vampirism")) > 0 && r.nextDouble(100) < 15 + 10 * l) {
            double max = p.getAttribute(org.bukkit.attribute.Attribute.MAX_HEALTH).getValue();
            p.setHealth(Math.min(max, p.getHealth() + l));
            p.getWorld().spawnParticle(Particle.HEART, p.getLocation().add(0, 2, 0), 2);
        }
        if ((l = level(w, "wither")) > 0 && r.nextDouble(100) < 10 * l)
            victim.addPotionEffect(new PotionEffect(PotionEffectType.WITHER, 60 + 20 * l, 1));
        if ((l = level(w, "venom")) > 0 && r.nextDouble(100) < 12 * l)
            victim.addPotionEffect(new PotionEffect(PotionEffectType.POISON, 60 + 20 * l, l - 1));
        if ((l = level(w, "frost")) > 0 && r.nextDouble(100) < 12 * l) {
            victim.addPotionEffect(new PotionEffect(PotionEffectType.SLOWNESS, 60 + 20 * l, l - 1));
            victim.setFreezeTicks(Math.min(victim.getMaxFreezeTicks() + 60, victim.getFreezeTicks() + 80));
            victim.getWorld().spawnParticle(Particle.SNOWFLAKE, victim.getLocation().add(0, 1, 0), 20, 0.3, 0.5, 0.3, 0);
        }
        if ((l = level(w, "thunder")) > 0 && r.nextDouble(100) < 5 * l) {
            victim.getWorld().strikeLightningEffect(victim.getLocation());
            double dmg = 2 + 2 * l;
            Bukkit.getScheduler().runTask(plugin, () -> { if (!victim.isDead()) victim.damage(dmg); });
        }
    }

    @EventHandler
    public void onPlayerDeath(PlayerDeathEvent e) {
        Player killer = e.getEntity().getKiller();
        if (killer == null) return;
        int l = level(killer.getInventory().getItemInMainHand(), "beheading");
        if (l > 0 && ThreadLocalRandom.current().nextDouble(100) < 10 * l) {
            ItemStack head = new ItemStack(Material.PLAYER_HEAD);
            SkullMeta sm = (SkullMeta) head.getItemMeta();
            sm.setOwningPlayer(e.getEntity());
            sm.setDisplayName(Text.color("&cГолова " + e.getEntity().getName()));
            head.setItemMeta(sm);
            e.getDrops().add(head);
        }
    }

    @EventHandler
    public void onMobDeath(EntityDeathEvent e) {
        if (e.getEntity() instanceof Player || e.getEntity().getKiller() == null) return;
        int l = level(e.getEntity().getKiller().getInventory().getItemInMainHand(), "wisdom");
        if (l > 0) e.setDroppedExp((int) (e.getDroppedExp() * (1 + 0.5 * l)));
    }

    // ====================== Копание ======================
    @EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
    public void onBreak(BlockBreakEvent e) {
        Player p = e.getPlayer();
        ItemStack tool = p.getInventory().getItemInMainHand();
        if (level(tool, "drill") <= 0 || p.isSneaking() || drilling.contains(e.getBlock().getLocation())) return;
        RayTraceResult rt = p.rayTraceBlocks(6);
        BlockFace face = rt != null && rt.getHitBlockFace() != null ? rt.getHitBlockFace() : BlockFace.UP;
        Block center = e.getBlock();
        for (int a = -1; a <= 1; a++) for (int b = -1; b <= 1; b++) {
            if (a == 0 && b == 0) continue;
            Block bl = switch (face) {
                case UP, DOWN -> center.getRelative(a, 0, b);
                case NORTH, SOUTH -> center.getRelative(a, b, 0);
                default -> center.getRelative(0, a, b);
            };
            if (bl.getType().isAir() || bl.getType().getHardness() < 0 || bl.getType().getHardness() > 50) continue;
            if (!bl.isPreferredTool(tool)) continue;
            drilling.add(bl.getLocation());
            try {
                p.breakBlock(bl); // вызывает BlockBreakEvent -> уважает приваты/спавн
            } finally {
                drilling.remove(bl.getLocation());
            }
        }
    }

    @EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
    public void onDrop(BlockDropItemEvent e) {
        Player p = e.getPlayer();
        ItemStack tool = p.getInventory().getItemInMainHand();
        boolean smelt = level(tool, "autosmelt") > 0, tele = level(tool, "telepathy") > 0;
        if (!smelt && !tele) return;
        Iterator<Item> it = e.getItems().iterator();
        while (it.hasNext()) {
            Item item = it.next();
            ItemStack stack = item.getItemStack();
            if (smelt) {
                ItemStack res = smeltResult(stack);
                if (res != null) { item.setItemStack(res); stack = res; }
            }
            if (tele) {
                Map<Integer, ItemStack> left = p.getInventory().addItem(stack);
                if (left.isEmpty()) it.remove(); else item.setItemStack(left.values().iterator().next());
            }
        }
    }

    private final Map<Material, Optional<ItemStack>> smeltCache = new HashMap<>();

    private ItemStack smeltResult(ItemStack in) {
        if (in.hasItemMeta() && ru.shadowsmp.items.ItemRegistry.idOf(in) != null) return null;
        Optional<ItemStack> res = smeltCache.computeIfAbsent(in.getType(), m -> {
            ItemStack probe = new ItemStack(m);
            Iterator<Recipe> it = Bukkit.recipeIterator();
            while (it.hasNext()) {
                if (it.next() instanceof FurnaceRecipe fr && fr.getInputChoice().test(probe)) return Optional.of(fr.getResult());
            }
            return Optional.empty();
        });
        if (res.isEmpty()) return null;
        ItemStack r = res.get().clone();
        r.setAmount(in.getAmount() * r.getAmount());
        return r;
    }

    /** Пассивные эффекты от зачарований брони. */
    public Map<PotionEffectType, Integer> passive(Player p) {
        Map<PotionEffectType, Integer> m = new HashMap<>();
        PlayerInventory inv = p.getInventory();
        int s = level(inv.getBoots(), "swiftness");
        if (s > 0) m.put(PotionEffectType.SPEED, s - 1);
        if (level(inv.getHelmet(), "owl") > 0) m.put(PotionEffectType.NIGHT_VISION, 0);
        int v = 0;
        for (ItemStack a : inv.getArmorContents()) v += level(a, "vitality");
        if (v > 0 && p.getHealth() <= 8) m.put(PotionEffectType.REGENERATION, Math.min(2, v - 1));
        return m;
    }
}
