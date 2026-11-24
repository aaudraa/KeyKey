package io.github.aaudraa.ornekgiris;

import android.app.Activity;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.util.Base64;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import androidx.credentials.CreateCredentialResponse;
import androidx.credentials.CreatePublicKeyCredentialRequest;
import androidx.credentials.CreatePublicKeyCredentialResponse;
import androidx.credentials.CredentialManager;
import androidx.credentials.CredentialManagerCallback;
import androidx.credentials.GetCredentialRequest;
import androidx.credentials.GetCredentialResponse;
import androidx.credentials.GetPublicKeyCredentialOption;
import androidx.credentials.PublicKeyCredential;
import androidx.credentials.exceptions.CreateCredentialException;
import androidx.credentials.exceptions.GetCredentialException;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.PublicKey;
import java.security.SecureRandom;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;
import java.util.Arrays;
import org.json.JSONObject;

/**
 * Passkey denemesi (#186): Credential Manager ile giris.example.com için
 * passkey oluşturur ve onunla giriş yapar. Bir sitenin sunucusunun yapacağı
 * denetimi telefonda yapar: meydan okuma, tür, rpId özeti, bayraklar ve
 * oluşturmada kaydedilen açık anahtarla imza. Sonuç ekrana "SONUC ..." diye
 * yazılır; test onu ekrandan okur.
 */
public class PasskeyActivity extends Activity {
    private static final String RP_ID = "giris.example.com";
    private static final int FLAG_UP = 0x01;
    private static final int FLAG_UV = 0x04;
    private static final int FLAG_AT = 0x40;

    private final SecureRandom random = new SecureRandom();
    private CredentialManager manager;
    private TextView result;
    private String challenge;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        manager = CredentialManager.create(this);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        layout.setPadding(48, 240, 48, 48);

        Button create = new Button(this);
        create.setText("Passkey oluştur");
        create.setOnClickListener(view -> create());
        layout.addView(create);

        Button signIn = new Button(this);
        signIn.setText("Passkey ile gir");
        signIn.setOnClickListener(view -> signIn());
        layout.addView(signIn);

        result = new TextView(this);
        layout.addView(result);
        setContentView(layout);
    }

    private void create() {
        challenge = newChallenge();
        String json;
        try {
            json = new JSONObject()
                    .put("challenge", challenge)
                    .put("rp", new JSONObject().put("id", RP_ID).put("name", "Örnek Giriş"))
                    .put("user", new JSONObject()
                            .put("id", b64("keykey-ornek".getBytes(StandardCharsets.UTF_8)))
                            .put("name", "keykey")
                            .put("displayName", "KeyKey Örnek"))
                    .put("pubKeyCredParams", new org.json.JSONArray()
                            .put(new JSONObject().put("type", "public-key").put("alg", -7)))
                    .put("timeout", 120000)
                    .put("attestation", "none")
                    .put("authenticatorSelection", new JSONObject()
                            .put("residentKey", "required")
                            .put("userVerification", "required"))
                    .toString();
        } catch (Exception e) {
            show("SONUC hata=" + e);
            return;
        }
        manager.createCredentialAsync(
                this,
                new CreatePublicKeyCredentialRequest(json),
                null,
                getMainExecutor(),
                new CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException>() {
                    @Override
                    public void onResult(CreateCredentialResponse response) {
                        String registration =
                                ((CreatePublicKeyCredentialResponse) response).getRegistrationResponseJson();
                        show(checkRegistration(registration));
                    }

                    @Override
                    public void onError(CreateCredentialException e) {
                        show("SONUC olusturma-hatasi=" + e.getType() + " " + e.getMessage());
                    }
                });
    }

    private void signIn() {
        challenge = newChallenge();
        String json;
        try {
            json = new JSONObject()
                    .put("challenge", challenge)
                    .put("rpId", RP_ID)
                    .put("timeout", 120000)
                    .put("userVerification", "required")
                    .toString();
        } catch (Exception e) {
            show("SONUC hata=" + e);
            return;
        }
        GetCredentialRequest request = new GetCredentialRequest.Builder()
                .addCredentialOption(new GetPublicKeyCredentialOption(json))
                .build();
        manager.getCredentialAsync(
                this,
                request,
                null,
                getMainExecutor(),
                new CredentialManagerCallback<GetCredentialResponse, GetCredentialException>() {
                    @Override
                    public void onResult(GetCredentialResponse response) {
                        if (!(response.getCredential() instanceof PublicKeyCredential)) {
                            show("SONUC giris-hatasi=passkey-degil");
                            return;
                        }
                        String authentication = ((PublicKeyCredential) response.getCredential())
                                .getAuthenticationResponseJson();
                        show(checkAuthentication(authentication));
                    }

                    @Override
                    public void onError(GetCredentialException e) {
                        show("SONUC giris-hatasi=" + e.getType() + " " + e.getMessage());
                    }
                });
    }

    /** Oluşturma yanıtı: meydan okuma, tür, rpId, bayraklar; açık anahtar saklanır. */
    private String checkRegistration(String json) {
        try {
            JSONObject root = new JSONObject(json);
            String id = root.getString("id");
            JSONObject response = root.getJSONObject("response");
            String problem = checkClientData(response.getString("clientDataJSON"), "webauthn.create");
            if (problem != null) return "SONUC olusturma-reddedildi=" + problem;
            byte[] authData = unb64(response.getString("authenticatorData"));
            problem = checkAuthData(authData, FLAG_AT);
            if (problem != null) return "SONUC olusturma-reddedildi=" + problem;
            if (response.getInt("publicKeyAlgorithm") != -7) {
                return "SONUC olusturma-reddedildi=algoritma";
            }
            prefs().edit()
                    .putString("id", id)
                    .putString("publicKey", response.getString("publicKey"))
                    .apply();
            return "SONUC passkey-olusturuldu id=" + id;
        } catch (Exception e) {
            return "SONUC olusturma-reddedildi=" + e;
        }
    }

    /** Giriş yanıtı: kimlik, meydan okuma, rpId, bayraklar ve imza. */
    private String checkAuthentication(String json) {
        try {
            JSONObject root = new JSONObject(json);
            String id = root.getString("id");
            if (!id.equals(prefs().getString("id", null))) {
                return "SONUC giris-reddedildi=bilinmeyen-kimlik";
            }
            JSONObject response = root.getJSONObject("response");
            String clientData = response.getString("clientDataJSON");
            String problem = checkClientData(clientData, "webauthn.get");
            if (problem != null) return "SONUC giris-reddedildi=" + problem;
            byte[] authData = unb64(response.getString("authenticatorData"));
            problem = checkAuthData(authData, 0);
            if (problem != null) return "SONUC giris-reddedildi=" + problem;

            PublicKey key = KeyFactory.getInstance("EC")
                    .generatePublic(new X509EncodedKeySpec(unb64(prefs().getString("publicKey", ""))));
            Signature verifier = Signature.getInstance("SHA256withECDSA");
            verifier.initVerify(key);
            verifier.update(authData);
            verifier.update(MessageDigest.getInstance("SHA-256").digest(unb64(clientData)));
            if (!verifier.verify(unb64(response.getString("signature")))) {
                return "SONUC giris-reddedildi=imza";
            }
            String user = new String(unb64(response.getString("userHandle")), StandardCharsets.UTF_8);
            return "SONUC passkey-giris-dogrulandi kullanici=" + user;
        } catch (Exception e) {
            return "SONUC giris-reddedildi=" + e;
        }
    }

    private String checkClientData(String encoded, String type) throws Exception {
        JSONObject clientData = new JSONObject(new String(unb64(encoded), StandardCharsets.UTF_8));
        if (!type.equals(clientData.getString("type"))) return "tur";
        if (!challenge.equals(clientData.getString("challenge"))) return "meydan-okuma";
        if (!clientData.getString("origin").startsWith("android:apk-key-hash:")) return "origin";
        return null;
    }

    private String checkAuthData(byte[] authData, int requiredFlag) throws Exception {
        if (authData.length < 37) return "authenticatorData-kisa";
        byte[] rpIdHash = MessageDigest.getInstance("SHA-256")
                .digest(RP_ID.getBytes(StandardCharsets.UTF_8));
        if (!Arrays.equals(Arrays.copyOfRange(authData, 0, 32), rpIdHash)) return "rpId";
        int flags = authData[32] & 0xff;
        int required = FLAG_UP | FLAG_UV | requiredFlag;
        if ((flags & required) != required) return "bayraklar";
        return null;
    }

    private SharedPreferences prefs() {
        return getSharedPreferences("passkey", MODE_PRIVATE);
    }

    private String newChallenge() {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        return b64(bytes);
    }

    private void show(String text) {
        result.setText(text);
    }

    private static String b64(byte[] bytes) {
        return Base64.encodeToString(bytes, Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
    }

    private static byte[] unb64(String text) {
        return Base64.decode(text, Base64.URL_SAFE | Base64.NO_PADDING | Base64.NO_WRAP);
    }
}
