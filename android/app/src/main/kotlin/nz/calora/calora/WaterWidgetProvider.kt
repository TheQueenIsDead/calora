package nz.calora.calora

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class WaterWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it, widgetData) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action ?: return
        val manager = AppWidgetManager.getInstance(context)
        val prefs   = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)

        when (action) {
            ACTION_ADD, ACTION_REMOVE -> {
                val amount  = intent.getIntExtra(EXTRA_AMOUNT, 250)
                val today   = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                val stored  = prefs.getString(KEY_DATE, "") ?: ""
                // If the day has rolled over, treat the previous count as 0
                val base    = if (stored == today) prefs.getInt(KEY_WATER_ML, 0) else 0
                val newVal  = if (action == ACTION_ADD) (base + amount).coerceAtMost(99999)
                              else (base - amount).coerceAtLeast(0)
                prefs.edit()
                    .putString(KEY_DATE, today)
                    .putInt(KEY_WATER_ML, newVal)
                    .apply()
            }
            ACTION_TOGGLE -> {
                val current = prefs.getString(KEY_MODE, MODE_ADD) ?: MODE_ADD
                prefs.edit()
                    .putString(KEY_MODE, if (current == MODE_ADD) MODE_REMOVE else MODE_ADD)
                    .apply()
            }
        }

        val updated = es.antonborri.home_widget.HomeWidgetPlugin.getData(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, WaterWidgetProvider::class.java))
        ids.forEach { updateWidget(context, manager, it, updated) }
    }

    companion object {
        const val ACTION_ADD    = "nz.calora.calora.widget.ADD_WATER"
        const val ACTION_REMOVE = "nz.calora.calora.widget.REMOVE_WATER"
        const val ACTION_TOGGLE = "nz.calora.calora.widget.TOGGLE_MODE"
        const val EXTRA_AMOUNT  = "amount"
        const val KEY_WATER_ML  = "water_ml"
        const val KEY_DATE      = "water_date"
        const val KEY_MODE      = "widget_mode"
        const val MODE_ADD      = "add"
        const val MODE_REMOVE   = "remove"

        private val vesselLayouts = intArrayOf(R.id.vessel_0, R.id.vessel_1, R.id.vessel_2)
        private val vesselIcons   = intArrayOf(R.id.vessel_0_icon, R.id.vessel_1_icon, R.id.vessel_2_icon)
        private val vesselTexts   = intArrayOf(R.id.vessel_0_text, R.id.vessel_1_text, R.id.vessel_2_text)

        fun updateWidget(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            data: SharedPreferences,
        ) {
            val waterMl  = data.getInt("water_ml", 0)
            val targetMl = data.getInt("water_target_ml", 2000).coerceAtLeast(1)
            val count    = data.getInt("vessel_count", 1).coerceIn(1, 3)
            val mode     = data.getString(KEY_MODE, MODE_ADD) ?: MODE_ADD
            val isAdd    = mode == MODE_ADD

            val views = RemoteViews(context.packageName, R.layout.water_widget)

            // Open app on body tap
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            // Amount + progress
            views.setTextViewText(R.id.water_amount, "${formatMl(waterMl)} / ${formatMl(targetMl)}")
            val pct = ((waterMl.toLong() * 100) / targetMl).coerceIn(0, 100).toInt()
            views.setProgressBar(R.id.water_progress, 100, pct, false)

            // Segmented toggle pill — − on left, + on right (matches app)
            views.setOnClickPendingIntent(R.id.mode_toggle, toggleIntent(context))
            if (isAdd) {
                // + pill active (blue), − inactive
                views.setInt(R.id.toggle_add, "setBackgroundResource", R.drawable.widget_toggle_pill_add)
                views.setTextColor(R.id.toggle_add, android.graphics.Color.WHITE)
                views.setInt(R.id.toggle_remove, "setBackgroundResource", android.R.color.transparent)
                views.setTextColor(R.id.toggle_remove, android.graphics.Color.parseColor("#FF9EAAB5"))
            } else {
                // − pill active (red), + inactive
                views.setInt(R.id.toggle_remove, "setBackgroundResource", R.drawable.widget_toggle_pill_remove)
                views.setTextColor(R.id.toggle_remove, android.graphics.Color.WHITE)
                views.setInt(R.id.toggle_add, "setBackgroundResource", android.R.color.transparent)
                views.setTextColor(R.id.toggle_add, android.graphics.Color.parseColor("#FF9EAAB5"))
            }

            // Vessel buttons
            for (i in 0..2) {
                val name  = data.getString("vessel_${i}_name", null)
                val ml    = data.getInt("vessel_${i}_ml", defaultMl(i))
                val iconPath = data.getString("vessel_${i}_icon_path", null)

                if (i < count && name != null) {
                    views.setViewVisibility(vesselLayouts[i], View.VISIBLE)

                    // Icon: try rendered PNG first, fall back to default vector
                    if (iconPath != null) {
                        val bmp = BitmapFactory.decodeFile(iconPath)
                        if (bmp != null) {
                            views.setImageViewBitmap(vesselIcons[i], bmp)
                        }
                    }

                    // Button background and tint
                    if (isAdd) {
                        views.setInt(vesselLayouts[i], "setBackgroundResource", R.drawable.widget_btn_pill)
                        views.setTextColor(vesselTexts[i], android.graphics.Color.parseColor("#FF9EAAB5"))
                        views.setInt(vesselIcons[i], "setColorFilter", android.graphics.Color.parseColor("#FF9EAAB5"))
                    } else {
                        views.setInt(vesselLayouts[i], "setBackgroundResource", R.drawable.widget_btn_pill_subtract)
                        views.setTextColor(vesselTexts[i], android.graphics.Color.parseColor("#FFEF5350"))
                        views.setInt(vesselIcons[i], "setColorFilter", android.graphics.Color.parseColor("#FFEF5350"))
                    }
                    views.setTextViewText(vesselTexts[i], "${ml}ml")

                    val action = if (isAdd) ACTION_ADD else ACTION_REMOVE
                    views.setOnClickPendingIntent(vesselLayouts[i], vesselIntent(context, action, ml, i))
                } else {
                    views.setViewVisibility(vesselLayouts[i], View.GONE)
                }
            }

            manager.updateAppWidget(widgetId, views)
        }

        private fun vesselIntent(context: Context, action: String, amount: Int, code: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context, code,
                Intent(context, WaterWidgetProvider::class.java).apply {
                    this.action = action
                    putExtra(EXTRA_AMOUNT, amount)
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun toggleIntent(context: Context): PendingIntent =
            PendingIntent.getBroadcast(
                context, 99,
                Intent(context, WaterWidgetProvider::class.java).apply { action = ACTION_TOGGLE },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun formatMl(ml: Int): String =
            if (ml >= 1000) String.format("%.1fL", ml / 1000.0) else "${ml}ml"

        private fun defaultMl(i: Int) = when (i) { 0 -> 250; 1 -> 350; else -> 500 }
    }
}
