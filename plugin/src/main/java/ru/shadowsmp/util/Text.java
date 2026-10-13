package ru.shadowsmp.util;

import net.md_5.bungee.api.ChatColor;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Цвета: &a, &l и HEX &#RRGGBB, плюс градиент <g:#AA00FF:#FF55FF>текст</g>. */
public final class Text {
    private static final Pattern HEX = Pattern.compile("&#([A-Fa-f0-9]{6})");
    private static final Pattern GRADIENT = Pattern.compile("<g:#([A-Fa-f0-9]{6}):#([A-Fa-f0-9]{6})>(.*?)</g>");

    private Text() {}

    public static String color(String s) {
        if (s == null) return "";
        Matcher g = GRADIENT.matcher(s);
        StringBuilder sb = new StringBuilder();
        while (g.find()) {
            g.appendReplacement(sb, Matcher.quoteReplacement(gradient(g.group(3), g.group(1), g.group(2))));
        }
        g.appendTail(sb);
        s = sb.toString();
        Matcher m = HEX.matcher(s);
        sb = new StringBuilder();
        while (m.find()) {
            m.appendReplacement(sb, Matcher.quoteReplacement(ChatColor.of("#" + m.group(1)).toString()));
        }
        m.appendTail(sb);
        return ChatColor.translateAlternateColorCodes('&', sb.toString());
    }

    public static List<String> color(List<String> list) {
        List<String> out = new ArrayList<>();
        if (list != null) for (String s : list) out.add(color(s));
        return out;
    }

    public static String gradient(String text, String fromHex, String toHex) {
        java.awt.Color a = java.awt.Color.decode("#" + fromHex);
        java.awt.Color b = java.awt.Color.decode("#" + toHex);
        // сохраняем &l/&o и т.п. внутри градиента
        StringBuilder formats = new StringBuilder();
        StringBuilder out = new StringBuilder();
        int visible = 0;
        for (int i = 0; i < text.length(); i++) {
            if (text.charAt(i) == '&' && i + 1 < text.length() && "lmnokr".indexOf(text.charAt(i + 1)) >= 0) { i++; continue; }
            visible++;
        }
        int idx = 0;
        for (int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if (c == '&' && i + 1 < text.length() && "lmnokr".indexOf(text.charAt(i + 1)) >= 0) {
                char f = text.charAt(++i);
                if (f == 'r') formats.setLength(0); else formats.append('&').append(f);
                continue;
            }
            double t = visible <= 1 ? 0 : (double) idx / (visible - 1);
            int r = (int) (a.getRed() + (b.getRed() - a.getRed()) * t);
            int gg = (int) (a.getGreen() + (b.getGreen() - a.getGreen()) * t);
            int bb = (int) (a.getBlue() + (b.getBlue() - a.getBlue()) * t);
            out.append(String.format("&#%02X%02X%02X", r, gg, bb)).append(formats).append(c);
            idx++;
        }
        return out.toString();
    }

    public static String strip(String s) {
        return ChatColor.stripColor(color(s));
    }

    public static String formatNumber(double v) {
        if (v == Math.floor(v)) return String.format("%,d", (long) v).replace(',', ' ');
        return String.format("%,.2f", v).replace(',', ' ');
    }

    public static String formatTime(long seconds) {
        long h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60;
        if (h > 0) return h + "ч " + m + "м";
        if (m > 0) return m + "м " + s + "с";
        return s + "с";
    }
}
