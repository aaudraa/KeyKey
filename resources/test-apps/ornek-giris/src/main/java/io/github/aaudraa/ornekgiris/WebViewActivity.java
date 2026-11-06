package io.github.aaudraa.ornekgiris;

import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;

/**
 * Tarayıcı olmayan bir uygulamada WebView içindeki giriş formu. Sayfa bir
 * banka alan adıyla yüklenir; KeyKey bu alan adına güvenmemeli (AutoSpill).
 */
public class WebViewActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView web = new WebView(this);
        String domain = getIntent().getStringExtra("alan");
        if (domain == null) domain = "banka.example.com";
        String html = "<html><body style='padding:24px'>"
                + "<form><input type='email' name='email' placeholder='E-posta'><br>"
                + "<input type='password' name='password' placeholder='Parola'><br>"
                + "<input type='submit' value='Giriş'></form></body></html>";
        web.loadDataWithBaseURL("https://" + domain + "/giris", html, "text/html", "utf-8", null);
        setContentView(web);
    }
}
