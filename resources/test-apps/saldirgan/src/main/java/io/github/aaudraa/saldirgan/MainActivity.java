package io.github.aaudraa.saldirgan;

import android.app.Activity;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.os.Bundle;
import android.view.Gravity;
import android.view.WindowManager;
import android.widget.TextView;

/**
 * Ekranın tamamını kaplayan, dokunuşları alttaki uygulamaya geçiren yarı
 * saydam bir bindirme penceresi açar ya da kapatır, sonra hemen kapanır.
 * Pencere uygulamanın sürecinde kalır.
 *
 * Opaklık 0,5: Android 12 ve sonrası 0,8'den opak pencerelerden geçen
 * dokunuşları kendisi engeller; 0,5 bu engelden geçer, yani en zor durum.
 */
public class MainActivity extends Activity {
    private static TextView overlay;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WindowManager windows = getApplicationContext().getSystemService(WindowManager.class);
        String mode = getIntent().getStringExtra("mod");
        if ("kapat".equals(mode)) {
            if (overlay != null) {
                windows.removeView(overlay);
                overlay = null;
            }
        } else if (overlay == null) {
            TextView view = new TextView(getApplicationContext());
            view.setText("SALDIRGAN BİNDİRME\nTebrikler, ödül kazandınız!");
            view.setTextSize(28);
            view.setTextColor(Color.WHITE);
            view.setBackgroundColor(Color.RED);
            view.setGravity(Gravity.CENTER);
            WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.MATCH_PARENT,
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                    WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                            | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                            | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                    PixelFormat.TRANSLUCENT);
            params.alpha = 0.5f;
            windows.addView(view, params);
            overlay = view;
        }
        finish();
    }
}
