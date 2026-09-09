package de.ianeo.movie_manager

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Barre de navigation système NOIRE, sans voile de contraste gris.
        // Complète la couleur définie côté Flutter et garantit le noir même si
        // la surcouche constructeur applique un fond par défaut.
        window.navigationBarColor = Color.BLACK
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
        }
    }
}
