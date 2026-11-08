package io.github.aaudraa.saldirgan;

import android.accessibilityservice.AccessibilityService;
import android.util.Log;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;
import java.util.ArrayList;
import java.util.List;

/**
 * KeyKey penceresinden okuyabildiği metinleri sayar ve logcat'e yazar
 * ("KKOKUYUCU" etiketi). Test betiği sayılara bakar: Android 14 ve sonrasında
 * KeyKey'den hiçbir metin okunamamalı.
 */
public class ReaderService extends AccessibilityService {
    private static final String TAG = "KKOKUYUCU";
    private static final String TARGET = "io.github.aaudraa.keykey";

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
        CharSequence source = event.getPackageName();
        boolean fromTarget = source != null && TARGET.contentEquals(source);
        int windowsWithTarget = 0;
        int windowsTotal = 0;
        List<String> texts = new ArrayList<>();
        int nodes = 0;
        for (AccessibilityWindowInfo window : getWindows()) {
            windowsTotal++;
            AccessibilityNodeInfo root = window.getRoot();
            if (root == null || root.getPackageName() == null
                    || !TARGET.contentEquals(root.getPackageName())) {
                continue;
            }
            windowsWithTarget++;
            nodes += collect(root, texts, 0);
        }
        // Her olay yazılır: başka uygulamalardan (ör. klavye) olay gelirken
        // KeyKey penceresinin okunamadığı da görünsün.
        String sample = texts.isEmpty() ? "-" : String.join(" | ", texts.subList(0, Math.min(3, texts.size())));
        Log.i(TAG, "olay=" + AccessibilityEvent.eventTypeToString(event.getEventType())
                + " paket=" + source
                + " olay_kaynagi_keykey=" + fromTarget
                + " pencere_toplam=" + windowsTotal
                + " pencere=" + windowsWithTarget
                + " dugum=" + nodes
                + " metin=" + texts.size()
                + " ornek=" + sample);
    }

    private int collect(AccessibilityNodeInfo node, List<String> texts, int depth) {
        if (node == null || depth > 60) return 0;
        int count = 1;
        CharSequence text = node.getText();
        CharSequence description = node.getContentDescription();
        if (text != null && text.length() > 0) texts.add(text.toString());
        else if (description != null && description.length() > 0) texts.add(description.toString());
        for (int i = 0; i < node.getChildCount(); i++) {
            count += collect(node.getChild(i), texts, depth + 1);
        }
        return count;
    }

    @Override
    public void onInterrupt() {
    }
}
