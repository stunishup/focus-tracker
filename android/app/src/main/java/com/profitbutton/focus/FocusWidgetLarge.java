package com.profitbutton.focus;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.RemoteViews;

public class FocusWidgetLarge extends AppWidgetProvider {

    static final String ACTION_ADD_HOUR_LARGE = "com.profitbutton.focus.ADD_HOUR_LARGE";

    @Override
    public void onUpdate(Context context, AppWidgetManager appWidgetManager, int[] appWidgetIds) {
        for (int widgetId : appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId);
        }
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        if (ACTION_ADD_HOUR_LARGE.equals(intent.getAction())) {
            FocusWidgetSmall.addHour(context);
            AppWidgetManager manager = AppWidgetManager.getInstance(context);
            int[] ids = manager.getAppWidgetIds(
                new android.content.ComponentName(context, FocusWidgetLarge.class));
            onUpdate(context, manager, ids);
            // Also update small
            int[] smallIds = manager.getAppWidgetIds(
                new android.content.ComponentName(context, FocusWidgetSmall.class));
            FocusWidgetSmall small = new FocusWidgetSmall();
            small.onUpdate(context, manager, smallIds);
        }
    }

    static void updateWidget(Context context, AppWidgetManager manager, int widgetId) {
        WeekManager.closeWeekIfNeeded(context);
        SharedPreferences prefs = context.getSharedPreferences(
            FocusWidgetSmall.PREFS_NAME, Context.MODE_PRIVATE);

        int currentHours = (int) prefs.getLong("flutter.currentHours", 0);
        int goal = (int) prefs.getLong("flutter.goal", 10);
        int totalUsed = (int) prefs.getLong("flutter.totalUsed", 0);
        int totalLost = (int) prefs.getLong("flutter.totalLost", 0);
        int totalOvertime = (int) prefs.getLong("flutter.totalOvertime", 0);
        String weekDates = prefs.getString("flutter.weekDates", "пн — нд");
        // fallback if home_widget hasn't written yet
        if (weekDates == null) weekDates = "пн — нд";

        int displayHours = Math.min(currentHours, goal);
        int risk = Math.max(0, goal - currentHours);
        boolean done = currentHours >= goal;
        int overtime = Math.max(0, currentHours - goal);
        int progress = (int) (Math.min(1.0f, (float) currentHours / goal) * 100);

        String riskText;
        int riskColor;
        if (done) {
            riskText = overtime > 0
                ? "Жодної не втрачено  +" + overtime + " год ⚡"
                : "✓  Жодної години не втрачено";
            riskColor = 0xFF22C55E;
        } else {
            riskText = "Ризик втратити " + risk + " " + FocusWidgetSmall.hoursWord(risk);
            riskColor = risk <= 2 ? 0xFFF59E0B : 0xFFEF4444;
        }

        RemoteViews views = new RemoteViews(context.getPackageName(), R.layout.focus_widget_large);
        views.setTextViewText(R.id.widget_large_dates, weekDates);
        views.setTextViewText(R.id.widget_large_hours, String.valueOf(displayHours));
        views.setTextViewText(R.id.widget_large_goal, String.valueOf(goal));
        views.setTextViewText(R.id.widget_large_risk, riskText);
        views.setTextColor(R.id.widget_large_risk, riskColor);
        views.setTextViewText(R.id.widget_large_used, totalUsed + " год");
        views.setTextViewText(R.id.widget_large_lost, totalLost + " год");
        views.setTextViewText(R.id.widget_large_over, totalOvertime + " год");

        // +1 button
        Intent addIntent = new Intent(context, FocusWidgetLarge.class);
        addIntent.setAction(ACTION_ADD_HOUR_LARGE);
        PendingIntent addPending = PendingIntent.getBroadcast(context, 2, addIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_large_btn_add, addPending);

        // Open app button
        Intent openIntent = new Intent(context, MainActivity.class);
        openIntent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP);
        PendingIntent openPending = PendingIntent.getActivity(context, 3, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        views.setOnClickPendingIntent(R.id.widget_large_btn_open, openPending);

        manager.updateAppWidget(widgetId, views);
    }
}
