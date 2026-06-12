package nz.calora.calora

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class CalorieWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val imagePath = widgetData.getString("calorie_ring_path", null)

        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.calorie_widget)

            // Tap opens the app
            views.setOnClickPendingIntent(
                R.id.calorie_widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            // Load rendered PNG from Flutter
            if (imagePath != null) {
                val bmp = BitmapFactory.decodeFile(imagePath)
                if (bmp != null) {
                    views.setImageViewBitmap(R.id.calorie_ring_image, bmp)
                }
            }

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
