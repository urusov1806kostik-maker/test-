package ru.shadowsmp.items;

import org.bukkit.*;
import org.bukkit.attribute.Attribute;
import org.bukkit.attribute.AttributeInstance;
import org.bukkit.attribute.AttributeModifier;
import org.bukkit.entity.*;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.entity.EntityDamageByEntityEvent;
import org.bukkit.event.entity.EntityResurrectEvent;
import org.bukkit.event.player.PlayerQuitEvent;
import org.bukkit.inventory.EquipmentSlot;
import org.bukkit.inventory.EquipmentSlotGroup;
import org.bukkit.inventory.ItemStack;
import org.bukkit.inventory.PlayerInventory;
import org.bukkit.potion.PotionEffect;
import org.bukkit.potion.PotionEffectType;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.util.EffectSpec;

import java.util.*;
import java.util.concurrent.ThreadLocalRandom;

/** Пассивки талисманов/кастом-предметов и боевые эффекты (кто бьёт / кого бьют). */
public class TalismanManager implements Listener {
    private final ShadowSMP plugin;
    private final Map<UUID, Set<PotionEffectType>> applied = new HashMap<>();

    public TalismanManager(ShadowSMP plugin) {
        this.plugin = plugin;
        Bukkit.getScheduler().runTaskTimer(plugin, this::tick, 40, 20);
    }

    /** Активные талисманы игрока (по умолчанию — в левой руке). */
    public List<ItemDef> activeTalismans(Player p) {
        String mode = plugin.getConfig().getString("talismans.active-slot", "OFFHAND").toUpperCase();
        int max = plugin.getConfig().getInt("talismans.max-active", 1);
        LinkedHashMap<String, ItemDef> found = new LinkedHashMap<>();
        PlayerInventory inv = p.getInventory();
        List<ItemStack> check = new ArrayList<>();
        check.add(inv.getItemInOffHand());
        if (mode.equals("HOTBAR")) for (int i = 0; i < 9; i++) check.add(inv.getItem(i));
        if (mode.equals("INVENTORY")) check.addAll(Arrays.asList(inv.getStorageContents()));
        for (ItemStack it : check) {
            ItemDef d = plugin.items().def(it);
            if (d != null && d.isTalisman()) found.putIfAbsent(d.fullId(), d);
            if (found.size() >= max) break;
        }
        return new ArrayList<>(found.values());
    }

    /** Все источники эффектов: талисманы + кастом-предмет в руке + кастом-броня. */
    public List<ItemDef> sources(Player p) {
        List<ItemDef> list = new ArrayList<>(activeTalismans(p));
        ItemDef hand = plugin.items().def(p.getInventory().getItemInMainHand());
        if (hand != null && !hand.isTalisman()) list.add(hand);
        for (ItemStack armor : p.getInventory().getArmorContents()) {
            ItemDef d = plugin.items().def(armor);
            if (d != null && !d.isTalisman()) list.add(d);
        }
        return list;
    }

    private void tick() {
        for (Player p : Bukkit.getOnlinePlayers()) {
            if (!plugin.auth().isLoggedIn(p)) continue;
            Map<PotionEffectType, Integer> want = new HashMap<>();
            Map<Attribute, Double> attrs = new HashMap<>();
            for (ItemDef d : activeTalismans(p)) {
                for (EffectSpec e : d.passive()) want.merge(e.type(), e.amplifier(), Math::max);
                d.attributes().forEach((a, v) -> attrs.merge(a, v, Double::sum));
            }
            ItemDef hand = plugin.items().def(p.getInventory().getItemInMainHand());
            if (hand != null && !hand.isTalisman()) for (EffectSpec e : hand.passive()) want.merge(e.type(), e.amplifier(), Math::max);
            for (ItemStack armor : p.getInventory().getArmorContents()) {
                ItemDef d = plugin.items().def(armor);
                if (d != null) for (EffectSpec e : d.passive()) want.merge(e.type(), e.amplifier(), Math::max);
            }
            plugin.enchants().passive(p).forEach((t, a) -> want.merge(t, a, Math::max));

            Set<PotionEffectType> prev = applied.getOrDefault(p.getUniqueId(), Set.of());
            for (PotionEffectType t : prev) {
                if (!want.containsKey(t)) {
                    PotionEffect cur = p.getPotionEffect(t);
                    if (cur != null && cur.isAmbient()) p.removePotionEffect(t);
                }
            }
            want.forEach((t, amp) -> {
                int dur = t.equals(PotionEffectType.NIGHT_VISION) ? 400 : 60;
                PotionEffect cur = p.getPotionEffect(t);
                if (cur == null || cur.isAmbient() || cur.getAmplifier() < amp)
                    p.addPotionEffect(new PotionEffect(t, dur, amp, true, false, true));
            });
            applied.put(p.getUniqueId(), new HashSet<>(want.keySet()));
            applyAttributes(p, attrs);
        }
    }

    private void applyAttributes(Player p, Map<Attribute, Double> attrs) {
        for (Attribute a : Registry.ATTRIBUTE) {
            AttributeInstance inst = p.getAttribute(a);
            if (inst == null) continue;
            NamespacedKey key = new NamespacedKey(plugin, "talisman_" + a.getKey().getKey());
            Double v = attrs.get(a);
            AttributeModifier existing = null;
            for (AttributeModifier m : inst.getModifiers()) if (m.getKey().equals(key)) existing = m;
            if (existing != null && v != null && existing.getAmount() == v) continue;
            if (existing != null) inst.removeModifier(existing);
            if (v != null) inst.addModifier(new AttributeModifier(key, v, AttributeModifier.Operation.ADD_NUMBER, EquipmentSlotGroup.ANY));
        }
        AttributeInstance hp = p.getAttribute(Attribute.MAX_HEALTH);
        if (hp != null && p.getHealth() > hp.getValue()) p.setHealth(hp.getValue());
    }

    @EventHandler
    public void onQuit(PlayerQuitEvent e) {
        applied.remove(e.getPlayer().getUniqueId());
    }

    /** Талисман не работает как тотем бессмертия (если не включено в конфиге). */
    @EventHandler(ignoreCancelled = true)
    public void onResurrect(EntityResurrectEvent e) {
        if (plugin.getConfig().getBoolean("talismans.act-as-totem", false)) return;
        if (!(e.getEntity() instanceof Player p)) return;
        EquipmentSlot hand = e.getHand();
        if (hand == null) return;
        ItemDef d = plugin.items().def(p.getInventory().getItem(hand));
        if (d != null && d.isTalisman()) e.setCancelled(true);
    }

    @EventHandler(priority = EventPriority.HIGH, ignoreCancelled = true)
    public void onCombat(EntityDamageByEntityEvent e) {
        if (!(e.getEntity() instanceof LivingEntity victim)) return;
        Player attacker = null;
        if (e.getDamager() instanceof Player p) attacker = p;
        else if (e.getDamager() instanceof Projectile pr && pr.getShooter() instanceof Player p) attacker = p;
        LivingEntity attackerLiving = attacker != null ? attacker
                : e.getDamager() instanceof LivingEntity l ? l
                : e.getDamager() instanceof Projectile pr && pr.getShooter() instanceof LivingEntity l2 ? l2 : null;
        ThreadLocalRandom r = ThreadLocalRandom.current();

        // === Того, кого ударили ===
        if (victim instanceof Player vp) {
            List<ItemDef> src = sources(vp);
            double dodge = 0, thorns = 0;
            int fire = 0;
            for (ItemDef d : src) {
                dodge += d.combat().dodgeChance();
                thorns += d.combat().thorns();
                fire = Math.max(fire, d.combat().hurtFire());
            }
            if (dodge > 0 && r.nextDouble(100) < Math.min(dodge, 75)) {
                e.setCancelled(true);
                vp.getWorld().spawnParticle(Particle.LARGE_SMOKE, vp.getLocation().add(0, 1, 0), 15, 0.3, 0.5, 0.3, 0.02);
                vp.playSound(vp.getLocation(), Sound.ENTITY_PHANTOM_FLAP, 1f, 1.4f);
                plugin.board().actionBar(vp, "&5&l✦ Уклонение!");
                return;
            }
            for (ItemDef d : src) {
                d.combat().hurtAttacker().forEach(x -> x.apply(attackerLiving));
                d.combat().hurtSelf().forEach(x -> x.apply(vp));
            }
            if (attackerLiving != null) {
                if (fire > 0) attackerLiving.setFireTicks(Math.max(attackerLiving.getFireTicks(), fire));
                if (thorns > 0) {
                    double dmg = e.getDamage() * thorns / 100.0;
                    LivingEntity target = attackerLiving;
                    Bukkit.getScheduler().runTask(plugin, () -> { if (!target.isDead()) target.damage(dmg); });
                }
            }
        }

        // === Того, кто бьёт ===
        if (attacker != null) {
            Player atk = attacker;
            List<ItemDef> src = sources(attacker);
            double bonus = 0, lifesteal = 0, lightning = 0;
            int fire = 0;
            for (ItemDef d : src) {
                bonus += d.combat().bonusDamage();
                lifesteal += d.combat().lifesteal();
                lightning += d.combat().lightningChance();
                fire = Math.max(fire, d.combat().hitFire());
                d.combat().hitTarget().forEach(x -> x.apply(victim));
                d.combat().hitSelf().forEach(x -> x.apply(atk));
            }
            if (bonus != 0) e.setDamage(e.getDamage() * (1 + bonus / 100.0));
            if (fire > 0) victim.setFireTicks(Math.max(victim.getFireTicks(), fire));
            if (lightning > 0 && r.nextDouble(100) < lightning) {
                victim.getWorld().strikeLightningEffect(victim.getLocation());
                Bukkit.getScheduler().runTask(plugin, () -> { if (!victim.isDead()) victim.damage(4); });
            }
            if (lifesteal > 0) {
                double max = attacker.getAttribute(Attribute.MAX_HEALTH).getValue();
                attacker.setHealth(Math.min(max, attacker.getHealth() + e.getFinalDamage() * lifesteal / 100.0));
            }
        }
    }
}
