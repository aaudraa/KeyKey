package io.github.aaudraa.ornekgiris;

import android.app.Activity;
import android.os.Bundle;
import android.text.InputType;
import android.view.autofill.AutofillManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Düz bir giriş formu: kullanıcı adı, parola ve giriş düğmesi. */
public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        // Hedef SDK 35+ ekranı kenardan kenara çizer; form durum çubuğunun altında kalmasın.
        layout.setPadding(48, 240, 48, 48);

        EditText username = new EditText(this);
        username.setHint("Kullanıcı adı");
        username.setInputType(InputType.TYPE_CLASS_TEXT);
        username.setContentDescription("kullanici");
        layout.addView(username);

        EditText password = new EditText(this);
        password.setHint("Parola");
        password.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        password.setContentDescription("parola");
        layout.addView(password);

        TextView result = new TextView(this);
        Button login = new Button(this);
        login.setText("Giriş");
        login.setOnClickListener(view -> {
            // Test betiği sonucu ekrandan okur.
            result.setText("SONUC kullanici=" + username.getText() + " parola=" + password.getText());
            AutofillManager manager = getSystemService(AutofillManager.class);
            if (manager != null) manager.commit();
        });
        layout.addView(login);
        layout.addView(result);
        setContentView(layout);
    }
}
