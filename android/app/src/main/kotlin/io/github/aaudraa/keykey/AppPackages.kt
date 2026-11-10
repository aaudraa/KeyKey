package io.github.aaudraa.keykey

import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import java.io.ByteArrayOutputStream

/**
 * Kayda bağlı uygulamaların simgeleri. Yalnızca KeyKey'in görebildiği
 * (ana ekranda simgesi olan) uygulamalar okunur; `QUERY_ALL_PACKAGES`
 * istenmez. Simgeler diske yazılmaz.
 */
class AppPackages(private val context: Context) : AppPackagesApi {
    override fun appIcon(packageName: String, sizePx: Long): ByteArray? {
        val size = sizePx.toInt().coerceIn(1, 512)
        return try {
            val drawable = context.packageManager.getApplicationIcon(packageName)
            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            drawable.setBounds(0, 0, size, size)
            drawable.draw(Canvas(bitmap))
            ByteArrayOutputStream().use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                bitmap.recycle()
                out.toByteArray()
            }
        } catch (_: PackageManager.NameNotFoundException) {
            null
        }
    }

    override fun versionName(): String =
        context.packageManager.getPackageInfo(context.packageName, 0).versionName ?: ""
}
