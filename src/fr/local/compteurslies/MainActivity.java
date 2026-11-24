package fr.local.compteurslies;

import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Insets;
import android.os.Build;
import android.os.Bundle;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.webkit.JavascriptInterface;
import android.view.WindowInsets;
import android.view.WindowInsetsController;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.FrameLayout;

/**
 * Activité unique : affiche la page embarquée (assets/index.html) dans une WebView.
 * L'état des compteurs et du chrono est conservé dans le localStorage de la WebView.
 */
public class MainActivity extends Activity {
    // Couleurs de fond de la page (--bg rose pastel, identique en mode sombre), visibles derrière les barres système
    private static final int BG_LIGHT = 0xFFFFC5D3;
    private static final int BG_DARK = 0xFFFFC5D3;

    private WebView web;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        boolean dark = (getResources().getConfiguration().uiMode
                & Configuration.UI_MODE_NIGHT_MASK) == Configuration.UI_MODE_NIGHT_YES;

        web = new WebView(this);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);                    // localStorage persistant
        s.setMediaPlaybackRequiresUserGesture(false);    // bip WebAudio du rappel sonore
        s.setAllowFileAccess(true);                      // nécessaire pour file:///android_asset
        s.setAllowContentAccess(false);
        s.setAllowFileAccessFromFileURLs(false);
        s.setAllowUniversalAccessFromFileURLs(false);
        // Pont de vibration exposé à la page (seule page chargée : l'asset local, pas de réseau)
        web.addJavascriptInterface(new Haptics(this), "AndroidHaptics");
        web.setBackgroundColor(dark ? BG_DARK : BG_LIGHT);

        // Conteneur qui reçoit les marges des barres système (Android 15 = edge-to-edge forcé)
        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(dark ? BG_DARK : BG_LIGHT);
        root.addView(web, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));
        if (Build.VERSION.SDK_INT >= 30) {
            root.setOnApplyWindowInsetsListener((v, insets) -> {
                Insets b = insets.getInsets(WindowInsets.Type.systemBars()
                        | WindowInsets.Type.displayCutout() | WindowInsets.Type.ime());
                v.setPadding(b.left, b.top, b.right, b.bottom);
                return WindowInsets.CONSUMED;
            });
        }
        setContentView(root);

        // Icônes de la barre d'état sombres : fond toujours rose clair
        if (Build.VERSION.SDK_INT >= 30) {
            WindowInsetsController c = getWindow().getInsetsController();
            if (c != null) {
                int light = WindowInsetsController.APPEARANCE_LIGHT_STATUS_BARS
                        | WindowInsetsController.APPEARANCE_LIGHT_NAVIGATION_BARS;
                c.setSystemBarsAppearance(light, light);
            }
        }

        if (savedInstanceState != null) {
            web.restoreState(savedInstanceState);
        } else {
            web.loadUrl("file:///android_asset/index.html");
        }
    }

    /** Vibrations appelées depuis le JavaScript (thread du pont WebView). */
    static final class Haptics {
        private final Vibrator vibrator;

        Haptics(Context ctx) {
            vibrator = (Vibrator) ctx.getSystemService(Context.VIBRATOR_SERVICE);
        }

        /** Mini vibration au clic sur + / −. */
        @JavascriptInterface
        public void tick() {
            if (vibrator == null || !vibrator.hasVibrator()) return;
            if (Build.VERSION.SDK_INT >= 29) {
                vibrator.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_CLICK));
            } else if (Build.VERSION.SDK_INT >= 26) {
                vibrator.vibrate(VibrationEffect.createOneShot(20, VibrationEffect.DEFAULT_AMPLITUDE));
            } else {
                vibrator.vibrate(20);
            }
        }

        /** Motif "vibre,pause,vibre,..." en ms (rappels, easter egg). */
        @JavascriptInterface
        public void pattern(String csv) {
            if (vibrator == null || !vibrator.hasVibrator() || csv == null) return;
            String[] parts = csv.split(",");
            if (parts.length == 0 || parts.length > 20) return;
            long[] timings = new long[parts.length + 1]; // timings[0] = délai initial
            try {
                for (int i = 0; i < parts.length; i++) {
                    timings[i + 1] = Math.max(0, Math.min(2000, Long.parseLong(parts[i].trim())));
                }
            } catch (NumberFormatException e) {
                return;
            }
            if (Build.VERSION.SDK_INT >= 26) {
                vibrator.vibrate(VibrationEffect.createWaveform(timings, -1));
            } else {
                vibrator.vibrate(timings, -1);
            }
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }

    @Override
    protected void onDestroy() {
        if (web != null) web.destroy();
        super.onDestroy();
    }
}
