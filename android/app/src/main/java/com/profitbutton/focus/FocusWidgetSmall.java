package com.profitbutton.focus;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

public class FocusWidgetSmall extends AppWidgetProvider {

    static final String ACTION_ADD_HOUR = "com.profitbutton.focus.ADD_HOUR";
    static final String PREFS_NAME = "FlutterSharedPreferences";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int widgetId : appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if (ACTION_ADD_HOUR.equals(intent.getAction())) {
            addHour(context);
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            int[] ids = manager.getAppWidgetIds(
                new android.content.ComponentName(context, FocusWidgetSmall.class));
            onUpdate(context, manager, ids);
            // Also update large widget
            int[] largeIds = manager.getAppWidgetIds(
                new android.content.ComponentName(context, FocusWidgetLarge.class));
            FocusWidgetLarge large = new FocusWidgetLarge();
            large.onUpdate(context, manager, largeIds);
        }
    }

    static void addHour(Context context) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        // Flutter stores as "flutter." prefix
        int current = (int) prefs.getLong("flutter.currentHours", 0);
        prefs.edit().putLong("flutter.currentHours", current + 1).apply();
    }

    static void updateWidget(Context context, AppWidgetManager manager, int widgetId) {
        SharedPreferences prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE);
        int currentHours = (int) prefs.getLong("flutter.currentHours", 0);
        int goal = (int) prefs.getLong("flutter.goal", 10);
        int totalLost = (int) prefs.getLong("flutter.totalLost", 0);

        int displayHours = Math.min(currentHours, goal);
        int risk = Math.max(0, goal - currentHours);
        boolean done = currentHours >= goal;
        int overtime = Math.max(0, currentHours - goal);

        String riskText;
        int riskColor;
        if (done) {
            riskText = overtime > 0
                ? "Жодної не втрачено +" + overtime + " ⚡"
                : "Жодної години не втрачено ✓";
            riskColor = 0xFF22C55E;
        } else {
            riskText = "Ризик втратити " + risk + " " + hoursWord(risk);
            riskColor = risk <= 2 ? 0xFFF59E0B : 0xFFEF4444;
        }

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.focus_widget_small);
        views.setTextViewText(R.id.widget_small_risk, riskText);
        views.setTextColor(R.id.widget_small_risk, riskColor);
        views.setTextViewText(R.id.widget_small_progress, displayHours + " / " + goal + " год");

        // +1 button
        Intent addIntent = new Intent(context, FocusWidgetSmall.class);
        addIntent.setAction(ACTION_ADD_HOUR);
        PendingIntent addPending = PendingIntent.getBroadcast(context, 0, addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_btn_add, addPending);

        // Tap on text → open app
        Intent openIntent = new Intent(context, MainActivity.class);
        openIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent openPending = PendingIntent.getActivity(context, 1, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_small_risk, openPending);

        manager.updateAppWidget(widgetId, views);
    }

    static String hoursWord(int n) {
        int mod100 = n % 100;
        int mod10 = n % 10;
        if (mod100 >= 11 && mod100 <= 19) return "годин";
        if (mod10 == 1) return "годину";
        if (mod10 >= 2 && mod10 <= 4) return "години";
        return "годин";
    }
}
