package ru.shadowsmp.board;

import net.luckperms.api.LuckPerms;
import net.luckperms.api.LuckPermsProvider;
import net.luckperms.api.model.group.Group;
import net.luckperms.api.model.user.User;
import org.bukkit.entity.Player;

/** Загружается только если LuckPerms установлен. */
final class LuckPermsHook {
    private final LuckPerms lp = LuckPermsProvider.get();

    String prefix(Player p) {
        User u = lp.getUserManager().getUser(p.getUniqueId());
        if (u == null) return "";
        String s = u.getCachedData().getMetaData().getPrefix();
        return s == null ? "" : s;
    }

    String group(Player p) {
        User u = lp.getUserManager().getUser(p.getUniqueId());
        return u == null ? "default" : u.getPrimaryGroup();
    }

    int weight(Player p) {
        Group g = lp.getGroupManager().getGroup(group(p));
        return g == null ? 0 : g.getWeight().orElse(0);
    }
}
