package ru.shadowsmp.util;

import org.bukkit.command.CommandSender;
import ru.shadowsmp.ShadowSMP;

public final class Msg {
    private Msg() {}

    public static String prefix() {
        return Text.color(ShadowSMP.get().getConfig().getString("prefix", "&8[&5ShadowSMP&8] &7"));
    }

    public static void send(CommandSender to, String msg) {
        to.sendMessage(prefix() + Text.color(msg));
    }
}
