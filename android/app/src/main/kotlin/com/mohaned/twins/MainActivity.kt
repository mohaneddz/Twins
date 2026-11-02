package com.mohaned.twins

import android.content.Intent
import android.os.Bundle
import androidx.core.app.Person
import androidx.core.content.pm.ShortcutInfoCompat
import androidx.core.content.pm.ShortcutManagerCompat
import androidx.core.graphics.drawable.IconCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Latest twins://join link the app was opened with, read by the setup
    // screen to connect to the inviting twin's project.
    private var inviteLink: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "twins/invite")
            .setMethodCallHandler { call, result ->
                if (call.method == "takeLink") {
                    result.success(inviteLink)
                    inviteLink = null
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "twins/shareShortcut")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "publish" -> {
                        publishSpaceShortcut(call.argument<String>("label") ?: "¡Twins!")
                        result.success(null)
                    }
                    "remove" -> {
                        ShortcutManagerCompat.removeLongLivedShortcuts(this, listOf(SHORTCUT_ID))
                        ShortcutManagerCompat.removeDynamicShortcuts(this, listOf(SHORTCUT_ID))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        reportShareUsage(intent)
        rememberInvite(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        reportShareUsage(intent)
        rememberInvite(intent)
    }

    private fun rememberInvite(intent: Intent?) {
        val data = intent?.data ?: return
        if (intent.action == Intent.ACTION_VIEW && data.scheme == "twins") inviteLink = data.toString()
    }

    // A long-lived shortcut with a Person is what Android ranks into the
    // share sheet's top row; one per device is enough since a user only
    // ever belongs to one space.
    private fun publishSpaceShortcut(label: String) {
        val shortcut = ShortcutInfoCompat.Builder(this, SHORTCUT_ID)
            .setShortLabel(label)
            .setLongLabel(label)
            .setIcon(IconCompat.createWithResource(this, R.mipmap.ic_launcher))
            .setIntent(Intent(this, MainActivity::class.java).setAction(Intent.ACTION_VIEW))
            .setLongLived(true)
            .setPerson(Person.Builder().setName(label).build())
            .setCategories(setOf(SHARE_CATEGORY))
            .build()
        ShortcutManagerCompat.pushDynamicShortcut(this, shortcut)
    }

    // Every share that lands here counts toward the ranking, whether it came
    // through the shortcut or the plain app target.
    private fun reportShareUsage(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND) {
            ShortcutManagerCompat.reportShortcutUsed(this, SHORTCUT_ID)
        }
    }

    private companion object {
        const val SHORTCUT_ID = "twinsSpace"
        const val SHARE_CATEGORY = "com.mohaned.twins.category.SHARE_TARGET"
    }
}
