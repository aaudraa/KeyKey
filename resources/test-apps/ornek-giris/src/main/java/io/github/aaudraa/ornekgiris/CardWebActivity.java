package io.github.aaudraa.ornekgiris;

import android.annotation.SuppressLint;
import android.app.Activity;
import android.os.Bundle;
import android.webkit.WebView;

/**
 * WebView içindeki HTML ödeme formu: `autocomplete` nitelikleri, açılır ay
 * ve yıl listeleri. Sayfa bir ödeme alan adıyla yüklenir.
 */
public class CardWebActivity extends Activity {
    @SuppressLint("SetJavaScriptEnabled")
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        WebView web = new WebView(this);
        // Yalnızca "Öde" düğmesinin sonucu yazması için.
        web.getSettings().setJavaScriptEnabled(true);
        StringBuilder months = new StringBuilder("<option value=''>Ay</option>");
        for (int i = 1; i <= 12; i++) {
            String value = String.format("%02d", i);
            months.append("<option value='").append(value).append("'>").append(value).append("</option>");
        }
        StringBuilder years = new StringBuilder("<option value=''>Yıl</option>");
        for (int i = 2026; i <= 2036; i++) {
            years.append("<option value='").append(i).append("'>").append(i).append("</option>");
        }
        String html = "<html><head><meta name='viewport' content='width=device-width'></head>"
                + "<body style='padding:24px;font-size:18px'><form>"
                + "<input autocomplete='cc-name' name='ad' placeholder='Kart sahibi'><br><br>"
                + "<input autocomplete='cc-number' name='numara' inputmode='numeric' placeholder='Kart numarası'><br><br>"
                + "<select autocomplete='cc-exp-month' name='ay'>" + months + "</select> "
                + "<select autocomplete='cc-exp-year' name='yil'>" + years + "</select><br><br>"
                + "<input autocomplete='cc-csc' name='kod' type='password' placeholder='CVC'><br><br>"
                + "<button type='button' onclick=\"var f=document.forms[0];document.getElementById('s').textContent="
                + "'SONUC numara='+f.numara.value+' sahip='+f.ad.value+' ay='+f.ay.value+' yil='+f.yil.value"
                + "+' kod='+f.kod.value\">Öde</button></form><p id='s'></p></body></html>";
        web.loadDataWithBaseURL("https://odeme.example.com/odeme", html, "text/html", "utf-8", null);
        setContentView(web);
    }
}
