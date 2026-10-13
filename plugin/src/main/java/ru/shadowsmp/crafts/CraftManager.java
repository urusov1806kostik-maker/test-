package ru.shadowsmp.crafts;

import org.bukkit.*;
import org.bukkit.configuration.ConfigurationSection;
import org.bukkit.configuration.file.YamlConfiguration;
import org.bukkit.entity.Player;
import org.bukkit.event.EventHandler;
import org.bukkit.event.EventPriority;
import org.bukkit.event.Listener;
import org.bukkit.event.inventory.*;
import org.bukkit.inventory.*;
import org.bukkit.inventory.meta.ItemMeta;
import org.bukkit.inventory.view.AnvilView;
import ru.shadowsmp.ShadowSMP;
import ru.shadowsmp.items.ItemRegistry;
import ru.shadowsmp.util.Text;

import java.io.File;
import java.util.*;

/** Кастомные крафты: верстак, печи, костёр, камнерез, кузнечный стол, наковальня. */
public class CraftManager implements Listener {
    private final ShadowSMP plugin;
    private final List<NamespacedKey> registered = new ArrayList<>();
    private final List<AnvilRecipe> anvil = new ArrayList<>();
    private final List<View> views = new ArrayList<>();

    record AnvilRecipe(String left, int leftAmount, String right, int rightAmount, ItemStack result, int xp) {}

    record View(String id, String type, ItemStack[] inputs, ItemStack result, String info) {}

    public CraftManager(ShadowSMP plugin) {
        this.plugin = plugin;
        reload();
    }

    public void reload() {
        registered.forEach(Bukkit::removeRecipe);
        registered.clear();
        anvil.clear();
        views.clear();
        YamlConfiguration y = YamlConfiguration.loadConfiguration(new File(plugin.getDataFolder(), "crafts.yml"));
        ConfigurationSection sec = y.getConfigurationSection("recipes");
        if (sec != null) for (String id : sec.getKeys(false)) {
            try {
                load(id, sec.getConfigurationSection(id));
            } catch (Exception ex) {
                plugin.getLogger().warning("Ошибка в crafts.yml -> " + id + ": " + ex.getMessage());
            }
        }
        for (Player p : Bukkit.getOnlinePlayers()) p.updateCommands();
        plugin.getLogger().info("Загружено рецептов: " + views.size());
    }

    private void load(String id, ConfigurationSection c) {
        String type = c.getString("type", "shaped").toLowerCase();
        ItemStack result = plugin.items().resolve(c.getString("result"));
        if (result == null) throw new IllegalArgumentException("неизвестный result");
        result.setAmount(c.getInt("amount", 1));
        NamespacedKey key = new NamespacedKey(plugin, id.toLowerCase());
        Recipe recipe = null;
        ItemStack[] in;
        String info = "";
        switch (type) {
            case "shaped" -> {
                ShapedRecipe r = new ShapedRecipe(key, result);
                List<String> shape = c.getStringList("shape");
                r.shape(shape.toArray(new String[0]));
                ConfigurationSection ing = c.getConfigurationSection("ingredients");
                in = new ItemStack[9];
                for (String k : ing.getKeys(false)) r.setIngredient(k.charAt(0), choice(ing.getString(k)));
                for (int row = 0; row < shape.size(); row++)
                    for (int col = 0; col < shape.get(row).length(); col++) {
                        char ch = shape.get(row).charAt(col);
                        if (ch != ' ') in[row * 3 + col] = display(ing.getString(String.valueOf(ch)));
                    }
                recipe = r;
                info = "&7Верстак";
            }
            case "shapeless" -> {
                ShapelessRecipe r = new ShapelessRecipe(key, result);
                List<String> ing = c.getStringList("ingredients");
                in = new ItemStack[9];
                for (int i = 0; i < ing.size(); i++) {
                    r.addIngredient(choice(ing.get(i)));
                    in[i] = display(ing.get(i));
                }
                recipe = r;
                info = "&7Верстак (без формы)";
            }
            case "furnace", "blasting", "smoking", "campfire" -> {
                RecipeChoice input = choice(c.getString("input"));
                float xp = (float) c.getDouble("xp", 1);
                int time = c.getInt("time", 200);
                recipe = switch (type) {
                    case "blasting" -> new BlastingRecipe(key, result, input, xp, time);
                    case "smoking" -> new SmokingRecipe(key, result, input, xp, time);
                    case "campfire" -> new CampfireRecipe(key, result, input, xp, time);
                    default -> new FurnaceRecipe(key, result, input, xp, time);
                };
                in = new ItemStack[]{display(c.getString("input"))};
                info = "&7" + switch (type) {
                    case "blasting" -> "Плавильная печь";
                    case "smoking" -> "Коптильня";
                    case "campfire" -> "Костёр";
                    default -> "Печь";
                } + " &8(" + time / 20 + " сек)";
            }
            case "stonecutting" -> {
                recipe = new StonecuttingRecipe(key, result, choice(c.getString("input")));
                in = new ItemStack[]{display(c.getString("input"))};
                info = "&7Камнерез";
            }
            case "smithing" -> {
                recipe = new SmithingTransformRecipe(key, result, choice(c.getString("template")),
                        choice(c.getString("base")), choice(c.getString("addition")));
                in = new ItemStack[]{display(c.getString("template")), display(c.getString("base")), display(c.getString("addition"))};
                info = "&7Кузнечный стол";
            }
            case "anvil" -> {
                String[] l = c.getString("left").split("\\*"), r = c.getString("right").split("\\*");
                int xp = c.getInt("xp", 5);
                anvil.add(new AnvilRecipe(l[0].trim(), l.length > 1 ? Integer.parseInt(l[1].trim()) : 1,
                        r[0].trim(), r.length > 1 ? Integer.parseInt(r[1].trim()) : 1, result, xp));
                in = new ItemStack[]{display(c.getString("left")), display(c.getString("right"))};
                info = "&7Наковальня &8(" + xp + " ур. опыта)";
            }
            default -> throw new IllegalArgumentException("неизвестный type: " + type);
        }
        if (recipe != null) {
            Bukkit.addRecipe(recipe);
            registered.add(key);
        }
        views.add(new View(id, type, in, result, info));
    }

    /** custom:/talisman:/book: -> точный предмет; #tag -> тег; иначе материал. */
    private RecipeChoice choice(String spec) {
        if (spec == null) throw new IllegalArgumentException("пустой ингредиент");
        spec = spec.split("\\*")[0].trim();
        if (spec.startsWith("#")) {
            Tag<Material> tag = Bukkit.getTag(Tag.REGISTRY_ITEMS, NamespacedKey.minecraft(spec.substring(1)), Material.class);
            if (tag == null) throw new IllegalArgumentException("неизвестный тег " + spec);
            return new RecipeChoice.MaterialChoice(tag);
        }
        ItemStack it = plugin.items().resolve(spec);
        if (it == null) throw new IllegalArgumentException("неизвестный ингредиент " + spec);
        if (spec.contains(":")) return new RecipeChoice.ExactChoice(it);
        return new RecipeChoice.MaterialChoice(it.getType());
    }

    private ItemStack display(String spec) {
        if (spec == null) return null;
        String[] p = spec.split("\\*");
        String s = p[0].trim();
        ItemStack it;
        if (s.startsWith("#")) {
            Tag<Material> tag = Bukkit.getTag(Tag.REGISTRY_ITEMS, NamespacedKey.minecraft(s.substring(1)), Material.class);
            it = new ItemStack(tag == null || tag.getValues().isEmpty() ? Material.BARRIER : tag.getValues().iterator().next());
        } else it = plugin.items().resolve(s);
        if (it == null) it = new ItemStack(Material.BARRIER);
        if (p.length > 1) it.setAmount(Integer.parseInt(p[1].trim()));
        return it;
    }

    private boolean matches(ItemStack it, String spec, int amount) {
        if (it == null || it.getAmount() < amount) return false;
        String id = ItemRegistry.idOf(it);
        if (spec.contains(":")) return spec.equalsIgnoreCase(id);
        Material m = Material.matchMaterial(spec);
        return m != null && it.getType() == m && id == null;
    }

    // ====================== Наковальня ======================
    @EventHandler(priority = EventPriority.HIGHEST)
    public void onAnvil(PrepareAnvilEvent e) {
        ItemStack l = e.getInventory().getItem(0), r = e.getInventory().getItem(1);
        for (AnvilRecipe ar : anvil) {
            if (matches(l, ar.left(), ar.leftAmount()) && matches(r, ar.right(), ar.rightAmount())) {
                if (ar.leftAmount() > 1 || l.getAmount() > ar.leftAmount()) {
                    // наковальня съедает весь левый слот — требуем ровно нужное кол-во
                    if (l.getAmount() != ar.leftAmount()) { e.setResult(null); return; }
                }
                AnvilView v = e.getView();
                e.setResult(ar.result().clone());
                v.setMaximumRepairCost(1000);
                v.setRepairCost(Math.max(1, ar.xp()));
                v.setRepairItemCountCost(ar.rightAmount());
                Bukkit.getScheduler().runTask(plugin, () -> {
                    v.setMaximumRepairCost(1000);
                    v.setRepairCost(Math.max(1, ar.xp()));
                    v.setRepairItemCountCost(ar.rightAmount());
                });
                return;
            }
        }
    }

    // ====================== Защита: кастом-предметы не идут в ванильные крафты ======================
    @EventHandler
    public void onCraft(PrepareItemCraftEvent e) {
        Recipe r = e.getRecipe();
        if (r instanceof Keyed k && k.getKey().getNamespace().equals(plugin.getName().toLowerCase())) return;
        for (ItemStack it : e.getInventory().getMatrix()) {
            if (ItemRegistry.idOf(it) != null) { e.getInventory().setResult(null); return; }
        }
    }

    @EventHandler
    public void onSmith(PrepareSmithingEvent e) {
        Recipe r = e.getInventory().getRecipe();
        if (r instanceof Keyed k && k.getKey().getNamespace().equals(plugin.getName().toLowerCase())) return;
        ItemStack base = e.getInventory().getItem(1);
        if (ItemRegistry.idOf(base) != null && e.getResult() != null) {
            // разрешаем улучшение кастом-предмета (например алмаз -> незерит), сохраняя его данные
            return;
        }
        ItemStack add = e.getInventory().getItem(2);
        if (ItemRegistry.idOf(add) != null) e.setResult(null);
    }

    // ====================== Просмотр рецептов ======================
    public static class Gui implements InventoryHolder {
        final int page;
        final View view;
        Inventory inv;

        Gui(int page, View view) { this.page = page; this.view = view; }

        @Override public Inventory getInventory() { return inv; }
    }

    public void openViewer(Player p, int page) {
        Gui g = new Gui(page, null);
        Inventory inv = Bukkit.createInventory(g, 54, Text.color("&5&lКастом крафты &8(стр. " + (page + 1) + ")"));
        g.inv = inv;
        int per = 45;
        for (int i = 0; i < per && page * per + i < views.size(); i++) {
            View v = views.get(page * per + i);
            ItemStack icon = v.result().clone();
            ItemMeta m = icon.getItemMeta();
            List<String> lore = m.hasLore() ? new ArrayList<>(m.getLore()) : new ArrayList<>();
            lore.add("");
            lore.add(Text.color(v.info()));
            lore.add(Text.color("&eНажми, чтобы посмотреть рецепт"));
            m.setLore(lore);
            icon.setItemMeta(m);
            inv.setItem(i, icon);
        }
        if (page > 0) inv.setItem(45, button(Material.ARROW, "&e← Назад"));
        if ((page + 1) * per < views.size()) inv.setItem(53, button(Material.ARROW, "&eВперёд →"));
        inv.setItem(49, button(Material.BARRIER, "&cЗакрыть"));
        p.openInventory(inv);
    }

    private void openDetail(Player p, View v, int page) {
        Gui g = new Gui(page, v);
        Inventory inv = Bukkit.createInventory(g, 54, Text.color("&5&lРецепт"));
        g.inv = inv;
        ItemStack pane = button(Material.BLACK_STAINED_GLASS_PANE, " ");
        for (int i = 0; i < 54; i++) inv.setItem(i, pane);
        if (v.type().startsWith("shape")) {
            int[] grid = {10, 11, 12, 19, 20, 21, 28, 29, 30};
            for (int i = 0; i < 9; i++) inv.setItem(grid[i], v.inputs()[i]);
        } else {
            int[] slots = v.inputs().length == 1 ? new int[]{20} : v.inputs().length == 2 ? new int[]{19, 21} : new int[]{19, 20, 21};
            for (int i = 0; i < v.inputs().length; i++) inv.setItem(slots[i], v.inputs()[i]);
        }
        inv.setItem(23, button(Material.SPECTRAL_ARROW, v.info()));
        inv.setItem(25, v.result());
        inv.setItem(49, button(Material.ARROW, "&e← К списку"));
        p.openInventory(inv);
    }

    private ItemStack button(Material m, String name) {
        ItemStack it = new ItemStack(m);
        ItemMeta meta = it.getItemMeta();
        meta.setDisplayName(Text.color(name));
        it.setItemMeta(meta);
        return it;
    }

    @EventHandler
    public void onClick(InventoryClickEvent e) {
        if (!(e.getInventory().getHolder() instanceof Gui g)) return;
        e.setCancelled(true);
        if (!(e.getWhoClicked() instanceof Player p) || e.getClickedInventory() != e.getInventory()) return;
        int slot = e.getSlot();
        if (g.view != null) {
            if (slot == 49) openViewer(p, g.page);
            return;
        }
        if (slot == 45 && g.page > 0) openViewer(p, g.page - 1);
        else if (slot == 53 && (g.page + 1) * 45 < views.size()) openViewer(p, g.page + 1);
        else if (slot == 49) p.closeInventory();
        else if (slot < 45 && g.page * 45 + slot < views.size()) openDetail(p, views.get(g.page * 45 + slot), g.page);
    }

    @EventHandler
    public void onDrag(InventoryDragEvent e) {
        if (e.getInventory().getHolder() instanceof Gui) e.setCancelled(true);
    }
}
