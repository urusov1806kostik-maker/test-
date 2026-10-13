package ru.shadowsmp;

import org.bukkit.Bukkit;
import org.bukkit.command.CommandExecutor;
import org.bukkit.command.PluginCommand;
import org.bukkit.command.TabCompleter;
import org.bukkit.event.Listener;
import org.bukkit.plugin.java.JavaPlugin;
import ru.shadowsmp.auth.AuthManager;
import ru.shadowsmp.board.BoardManager;
import ru.shadowsmp.commands.CustomCommandManager;
import ru.shadowsmp.commands.MainCommands;
import ru.shadowsmp.crafts.CraftManager;
import ru.shadowsmp.economy.Economy;
import ru.shadowsmp.economy.EconomyCommands;
import ru.shadowsmp.enchants.EnchantManager;
import ru.shadowsmp.events.EventManager;
import ru.shadowsmp.items.ItemRegistry;
import ru.shadowsmp.items.TalismanManager;
import ru.shadowsmp.npc.NpcManager;
import ru.shadowsmp.pack.ResourcePackManager;
import ru.shadowsmp.shop.Shop;
import ru.shadowsmp.spawn.SpawnManager;
import ru.shadowsmp.util.Keys;

import java.io.File;
import java.util.List;

public final class ShadowSMP extends JavaPlugin {
    private static ShadowSMP instance;
    private Economy economy;
    private ItemRegistry items;
    private EnchantManager enchants;
    private TalismanManager talismans;
    private CraftManager crafts;
    private SpawnManager spawn;
    private BoardManager board;
    private ResourcePackManager pack;
    private AuthManager auth;
    private EventManager events;
    private NpcManager npcs;
    private CustomCommandManager customCommands;
    private Shop shop;

    public static ShadowSMP get() { return instance; }

    @Override
    public void onEnable() {
        instance = this;
        saveDefaultConfig();
        for (String f : List.of("items.yml", "talismans.yml", "crafts.yml", "commands.yml", "shop.yml", "npcs.yml"))
            if (!new File(getDataFolder(), f).exists()) saveResource(f, false);
        Keys.init(this);

        economy = new Economy(this);
        enchants = new EnchantManager(this);
        items = new ItemRegistry(this);
        auth = new AuthManager(this);
        talismans = new TalismanManager(this);
        crafts = new CraftManager(this);
        spawn = new SpawnManager(this);
        pack = new ResourcePackManager(this);
        events = new EventManager(this);
        board = new BoardManager(this);
        npcs = new NpcManager(this);
        shop = new Shop(this);
        customCommands = new CustomCommandManager(this);

        for (Listener l : new Listener[]{auth, talismans, enchants, crafts, spawn, pack, events, board, npcs, shop})
            Bukkit.getPluginManager().registerEvents(l, this);
        EconomyCommands eco = new EconomyCommands(this);
        Bukkit.getPluginManager().registerEvents(eco, this);

        MainCommands main = new MainCommands(this);
        bind(main, "shadowsmp", "spawn", "setspawn", "buildspawn", "shop", "crafts", "sb", "talisman", "citem", "cenchant");
        bind(eco, "money", "mpay", "mtop", "seco");
        bind(auth, "register", "login", "changepassword", "logout", "unregister");
        bind(events, "event");
        bind(npcs, "npc");
        bind(customCommands, "ccmd");

        Bukkit.getScheduler().runTaskLater(this, this::setupLuckPerms, 100);
        getLogger().info("ShadowSMP запущен!");
    }

    private void bind(Object handler, String... names) {
        for (String n : names) {
            PluginCommand c = getCommand(n);
            if (c == null) continue;
            c.setExecutor((CommandExecutor) handler);
            if (handler instanceof TabCompleter t) c.setTabCompleter(t);
        }
    }

    /** Один раз создаёт группы LuckPerms с префиксами и правами (config.yml -> luckperms-setup). */
    private void setupLuckPerms() {
        if (Bukkit.getPluginManager().getPlugin("LuckPerms") == null || getConfig().getBoolean("luckperms-setup.done", false)) return;
        getLogger().info("Настраиваю группы LuckPerms...");
        for (String c : getConfig().getStringList("luckperms-setup.commands"))
            Bukkit.dispatchCommand(Bukkit.getConsoleSender(), c);
        getConfig().set("luckperms-setup.done", true);
        saveConfig();
    }

    public void reloadAll() {
        reloadConfig();
        items.reload();
        enchants.reload();
        crafts.reload();
        pack.reload();
        events.scheduleAuto();
        npcs.reload();
        shop.reload();
        customCommands.reload();
    }

    @Override
    public void onDisable() {
        if (events != null) events.stop();
        if (npcs != null) npcs.despawnAll();
        if (economy != null) economy.save();
    }

    public Economy economy() { return economy; }
    public ItemRegistry items() { return items; }
    public EnchantManager enchants() { return enchants; }
    public TalismanManager talismans() { return talismans; }
    public CraftManager crafts() { return crafts; }
    public SpawnManager spawn() { return spawn; }
    public BoardManager board() { return board; }
    public ResourcePackManager pack() { return pack; }
    public AuthManager auth() { return auth; }
    public EventManager events() { return events; }
    public NpcManager npcs() { return npcs; }
    public Shop shop() { return shop; }
}
