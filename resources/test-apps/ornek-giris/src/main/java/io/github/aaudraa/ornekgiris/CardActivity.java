package io.github.aaudraa.ornekgiris;

import android.app.Activity;
import android.os.Bundle;
import android.text.InputType;
import android.view.View;
import android.view.autofill.AutofillManager;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.Spinner;
import android.widget.TextView;
import java.util.ArrayList;
import java.util.List;

/**
 * Android ipuçlu ödeme formu: numara, kart sahibi, açılır ay ve yıl
 * listeleri, gizli rakam güvenlik kodu.
 */
public class CardActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(48, 240, 48, 48);

        EditText number = new EditText(this);
        number.setHint("Kart numarası");
        number.setInputType(InputType.TYPE_CLASS_NUMBER);
        number.setAutofillHints(View.AUTOFILL_HINT_CREDIT_CARD_NUMBER);
        layout.addView(number);

        EditText holder = new EditText(this);
        holder.setHint("Kart sahibi");
        holder.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS);
        layout.addView(holder);

        List<String> months = new ArrayList<>();
        months.add("Ay");
        for (int i = 1; i <= 12; i++) months.add(String.format("%02d", i));
        Spinner month = spinner(months, View.AUTOFILL_HINT_CREDIT_CARD_EXPIRATION_MONTH);
        layout.addView(month);

        List<String> years = new ArrayList<>();
        years.add("Yıl");
        for (int i = 2026; i <= 2036; i++) years.add(String.valueOf(i));
        Spinner year = spinner(years, View.AUTOFILL_HINT_CREDIT_CARD_EXPIRATION_YEAR);
        layout.addView(year);

        EditText code = new EditText(this);
        code.setHint("Güvenlik kodu");
        code.setInputType(InputType.TYPE_CLASS_NUMBER | InputType.TYPE_NUMBER_VARIATION_PASSWORD);
        code.setAutofillHints(View.AUTOFILL_HINT_CREDIT_CARD_SECURITY_CODE);
        layout.addView(code);

        TextView result = new TextView(this);
        Button pay = new Button(this);
        pay.setText("Öde");
        pay.setOnClickListener(view -> {
            // Test betiği sonucu ekrandan okur.
            result.setText("SONUC numara=" + number.getText() + " sahip=" + holder.getText()
                    + " ay=" + month.getSelectedItem() + " yil=" + year.getSelectedItem()
                    + " kod=" + code.getText());
            AutofillManager manager = getSystemService(AutofillManager.class);
            if (manager != null) manager.commit();
        });
        layout.addView(pay);
        layout.addView(result);
        setContentView(layout);
    }

    private Spinner spinner(List<String> items, String hint) {
        Spinner spinner = new Spinner(this);
        ArrayAdapter<String> adapter =
                new ArrayAdapter<>(this, android.R.layout.simple_spinner_item, items);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        // ArrayAdapter seçenekleri doldurma servisine yalnızca kaynak
        // dosyasından geliyorlarsa verir; kodda kurulan liste açıkça verilir.
        adapter.setAutofillOptions(items.toArray(new CharSequence[0]));
        spinner.setAdapter(adapter);
        spinner.setAutofillHints(hint);
        return spinner;
    }
}
