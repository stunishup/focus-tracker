package com.profitbutton.focus;

import android.content.Context;
import android.content.SharedPreferences;
import java.util.Calendar;
import java.util.TimeZone;

/**
 * Спільна логіка закриття тижня для віджетів (Java) та додатку (Dart).
 * Гарантує що при натисканні +1 на віджеті в новий тиждень спершу
 * закриється старий тиждень (як це робить Dart), і лише потім додасться година.
 */
public class WeekManager {

    static final String PREFS = "FlutterSharedPreferences";
    static final String P = "flutter.";

    // Поточний понеділок у форматі yyyy-MM-dd
    static String getWeekStart() {
        Calendar c = Calendar.getInstance(TimeZone.getDefault());
        c.set(Calendar.HOUR_OF_DAY, 0);
        c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
        // Calendar: неділя=1 ... субота=7. Нам треба понеділок як початок.
        int dow = c.get(Calendar.DAY_OF_WEEK);
        int diff = (dow == Calendar.SUNDAY) ? 6 : (dow - Calendar.MONDAY);
        c.add(Calendar.DAY_OF_MONTH, -diff);
        int y = c.get(Calendar.YEAR);
        int m = c.get(Calendar.MONTH) + 1;
        int d = c.get(Calendar.DAY_OF_MONTH);
        return String.format("%04d-%02d-%02d", y, m, d);
    }

    /**
     * Перевіряє чи настав новий тиждень. Якщо так — закриває попередній
     * (оновлює totalUsed/totalLost/totalOvertime/streak/totalWeeks/fullWeeks,
     * додає запис в history) і обнуляє currentHours.
     * Викликається ПЕРЕД будь-якою зміною годин з віджета.
     */
    static synchronized void closeWeekIfNeeded(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String today = getWeekStart();
        String stored = prefs.getString(P + "currentWeekStart", null);

        if (stored == null || stored.isEmpty()) {
            prefs.edit().putString(P + "currentWeekStart", today).apply();
            return;
        }
        if (stored.equals(today)) {
            return; // той самий тиждень — нічого не робимо
        }

        // ── Закриваємо старий тиждень ──
        int goal = (int) prefs.getLong(P + "goal", 10);
        int currentHours = (int) prefs.getLong(P + "currentHours", 0);

        int used = Math.min(currentHours, goal);
        int lost = Math.max(0, Math.min(goal - currentHours, goal));
        int over = Math.max(0, currentHours - goal);

        int totalUsed = (int) prefs.getLong(P + "totalUsed", 0) + used;
        int totalLost = (int) prefs.getLong(P + "totalLost", 0) + lost;
        int totalOvertime = (int) prefs.getLong(P + "totalOvertime", 0) + over;
        int totalWeeks = (int) prefs.getLong(P + "totalWeeks", 0) + 1;
        int streak = (int) prefs.getLong(P + "streak", 0);
        int fullWeeks = (int) prefs.getLong(P + "fullWeeks", 0);

        boolean isFull = currentHours >= goal;
        if (isFull) { streak += 1; fullWeeks += 1; } else { streak = 0; }

        // history зберігається Dart-ом як JSON-рядок. Додаємо новий запис на початок.
        String histJson = prefs.getString(P + "history", "[]");
        if (histJson == null || histJson.isEmpty()) histJson = "[]";

        String endDate = weekEndDate(stored);
        String newRecord = "{"
            + "\"weekStart\":\"" + stored + "\","
            + "\"weekEnd\":\"" + endDate + "\","
            + "\"hours\":" + currentHours + ","
            + "\"goal\":" + goal + ","
            + "\"used\":" + used + ","
            + "\"lost\":" + lost + ","
            + "\"over\":" + over + ","
            + "\"full\":" + (isFull ? "true" : "false")
            + "}";

        String updatedHist;
        String trimmed = histJson.trim();
        if (trimmed.equals("[]")) {
            updatedHist = "[" + newRecord + "]";
        } else {
            // вставляємо одразу після першої [
            updatedHist = "[" + newRecord + "," + trimmed.substring(1);
        }

        SharedPreferences.Editor e = prefs.edit();
        e.putLong(P + "totalUsed", totalUsed);
        e.putLong(P + "totalLost", totalLost);
        e.putLong(P + "totalOvertime", totalOvertime);
        e.putLong(P + "totalWeeks", totalWeeks);
        e.putLong(P + "streak", streak);
        e.putLong(P + "fullWeeks", fullWeeks);
        e.putString(P + "history", updatedHist);
        e.putString(P + "currentWeekStart", today);
        e.putLong(P + "currentHours", 0); // новий тиждень починається з нуля
        // оновлюємо рядок дат для великого віджета
        e.putString(P + "weekDates", formatRange(today));
        e.apply();
    }

    // Кінець тижня (неділя) = понеділок + 6 днів, формат yyyy-MM-dd
    static String weekEndDate(String weekStart) {
        try {
            String[] p = weekStart.split("-");
            Calendar c = Calendar.getInstance();
            c.set(Integer.parseInt(p[0]), Integer.parseInt(p[1]) - 1, Integer.parseInt(p[2]));
            c.add(Calendar.DAY_OF_MONTH, 6);
            return String.format("%04d-%02d-%02d",
                c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH));
        } catch (Exception ex) {
            return weekStart;
        }
    }

    static final String[] MONTHS = {"", "січ", "лют", "бер", "кві", "тра", "чер",
        "лип", "сер", "вер", "жов", "лис", "гру"};

    // "8 чер — 14 чер"
    static String formatRange(String weekStart) {
        try {
            String[] p = weekStart.split("-");
            Calendar c = Calendar.getInstance();
            c.set(Integer.parseInt(p[0]), Integer.parseInt(p[1]) - 1, Integer.parseInt(p[2]));
            int d1 = c.get(Calendar.DAY_OF_MONTH);
            int m1 = c.get(Calendar.MONTH) + 1;
            c.add(Calendar.DAY_OF_MONTH, 6);
            int d2 = c.get(Calendar.DAY_OF_MONTH);
            int m2 = c.get(Calendar.MONTH) + 1;
            return d1 + " " + MONTHS[m1] + " — " + d2 + " " + MONTHS[m2];
        } catch (Exception ex) {
            return "пн — нд";
        }
    }
}
