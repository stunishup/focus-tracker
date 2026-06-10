package com.profitbutton.focus;

import android.appwidget.AppWidgetManager;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;

public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            AppWidgetManager manager = AppWidgetManager.getInstance(context);

            int[] smallIds = manager.getAppWidgetIds(
                new ComponentName(context, FocusWidgetSmall.class));
            for (int id : smallIds) FocusWidgetSmall.updateWidget(context, manager, id);

            int[] largeIds = manager.getAppWidgetIds(
                new ComponentName(context, FocusWidgetLarge.class));
            for (int id : largeIds) FocusWidgetLarge.updateWidget(context, manager, id);
        }
    }
}
