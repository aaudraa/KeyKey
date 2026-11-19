package io.github.aaudraa.ornekgiris;

import android.app.Activity;
import android.os.Bundle;
import android.text.InputType;
import android.view.autofill.AutofillManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

/**
 * İpucusuz ödeme formu: alanlar yalnızca ipucu metinlerinden tanınabilir.
 * Güvenlik kodu gizli rakam kutusu; parola sanılmamalı.
 */
public class CardWordsActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(48, 240, 48, 48);

        EditText number = new EditText(this);
        number.setHint("Kart numarası");
        number.setInputType(InputType.TYPE_CLASS_NUMBER);
        layout.addView(number);

        EditText expiry = new EditText(this);
        expiry.setHint("Son kullanma (AA/YY)");
        expiry.setInputType(InputType.TYPE_CLASS_TEXT);
        layout.addView(expiry);

        EditText code = new EditText(this);
        code.setHint("CVV");
        code.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        layout.addView(code);

        TextView result = new TextView(this);
        Button pay = new Button(this);
        pay.setText("Öde");
        pay.setOnClickListener(view -> {
            result.setText("SONUC numara=" + number.getText() + " skt=" + expiry.getText()
                    + " kod=" + code.getText());
            AutofillManager manager = getSystemService(AutofillManager.class);
            if (manager != null) manager.commit();
        });
        layout.addView(pay);
        layout.addView(result);
        setContentView(layout);
    }
}
