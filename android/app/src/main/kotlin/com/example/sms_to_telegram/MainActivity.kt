package com.example.sms_to_telegram

import android.Manifest
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.example.sms_to_telegram/sms"
        var methodChannel: MethodChannel? = null
        private const val PERMISSION_REQUEST_CODE = 101
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startForegroundServiceInternal()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> {
                    val hasPermissions = checkAndRequestPermissions()
                    result.success(hasPermissions)
                }
                "checkOverlayPermission" -> {
                    val hasOverlayPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(hasOverlayPermission)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        if (!Settings.canDrawOverlays(this)) {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        }
                    }
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val isIgnoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        powerManager?.isIgnoringBatteryOptimizations(packageName) ?: false
                    } else {
                        true
                    }
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizationsInternal()
                    result.success(true)
                }
                "openAutoStartSettings" -> {
                    val opened = openAutoStartSettingsInternal()
                    result.success(opened)
                }
                "openAppDetails" -> {
                    openAppDetailsInternal()
                    result.success(true)
                }
                "getDeviceInfo" -> {
                    val info = mapOf(
                        "manufacturer" to (Build.MANUFACTURER ?: "Unknown"),
                        "model" to (Build.MODEL ?: "Unknown"),
                        "brand" to (Build.BRAND ?: "Unknown"),
                        "sdkVersion" to Build.VERSION.SDK_INT
                    )
                    result.success(info)
                }
                "getBatteryInfo" -> {
                    val batteryInfo = getBatteryInfoInternal()
                    result.success(batteryInfo)
                }
                "startForegroundService" -> {
                    startForegroundServiceInternal()
                    result.success(true)
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val installed = installApkInternal(filePath)
                        result.success(installed)
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun installApkInternal(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) return false

            val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    file
                )
            } else {
                Uri.fromFile(file)
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun requestIgnoreBatteryOptimizationsInternal() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as? PowerManager
            if (powerManager?.isIgnoringBatteryOptimizations(packageName) != true) {
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:$packageName")
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    try {
                        val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(fallbackIntent)
                    } catch (e2: Exception) {
                        openAppDetailsInternal()
                    }
                }
            }
        }
    }

    private fun openAutoStartSettingsInternal(): Boolean {
        val intents = listOf(
            // Xiaomi / MIUI / HyperOS
            Intent().setComponent(ComponentName("com.miui.securitycenter", "com.miui.permcenter.autostart.AutoStartManagementActivity")),
            Intent().setComponent(ComponentName("com.miui.powerkeeper", "com.miui.powerkeeper.ui.HiddenAppsConfigActivity")),
            // Oppo / Realme / ColorOS
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.permission.startup.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.coloros.safecenter", "com.coloros.safecenter.startupapp.StartupAppListActivity")),
            Intent().setComponent(ComponentName("com.oppo.safe", "com.oppo.safe.permission.startup.StartupAppListActivity")),
            // Vivo / iQOO / FuntouchOS
            Intent().setComponent(ComponentName("com.vivo.permissionmanager", "com.vivo.permissionmanager.activity.BgStartUpManagerActivity")),
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity")),
            Intent().setComponent(ComponentName("com.iqoo.secure", "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager")),
            // Samsung
            Intent().setComponent(ComponentName("com.samsung.android.lool", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            Intent().setComponent(ComponentName("com.samsung.android.sm", "com.samsung.android.sm.ui.battery.BatteryActivity")),
            // Huawei / Honor
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity")),
            Intent().setComponent(ComponentName("com.huawei.systemmanager", "com.huawei.systemmanager.optimize.process.ProtectActivity")),
            // OnePlus
            Intent().setComponent(ComponentName("com.oneplus.security", "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity")),
            // Asus
            Intent().setComponent(ComponentName("com.asus.mobilemanager", "com.asus.mobilemanager.autostart.AutoStartActivity"))
        )

        for (intent in intents) {
            try {
                intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(intent)
                return true
            } catch (_: Exception) {
                // Try next
            }
        }

        // Fallback to app details
        openAppDetailsInternal()
        return false
    }

    private fun openAppDetailsInternal() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun getBatteryInfoInternal(): Map<String, Any> {
        return try {
            val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
            val batteryStatus: Intent? = registerReceiver(null, filter)
            val level: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
            val scale: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
            val batteryPct: Int = if (level >= 0 && scale > 0) ((level.toFloat() / scale.toFloat()) * 100).toInt() else -1
            val status: Int = batteryStatus?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
            val isCharging: Boolean = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL

            mapOf(
                "batteryLevel" to batteryPct,
                "isCharging" to isCharging
            )
        } catch (e: Exception) {
            mapOf(
                "batteryLevel" to -1,
                "isCharging" to false
            )
        }
    }

    private fun startForegroundServiceInternal() {
        val serviceIntent = Intent(this, ForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ContextCompat.startForegroundService(this, serviceIntent)
        } else {
            startService(serviceIntent)
        }
    }

    private fun checkAndRequestPermissions(): Boolean {
        val permissionsList = mutableListOf(
            Manifest.permission.RECEIVE_SMS,
            Manifest.permission.READ_SMS
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionsList.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        val permissionsToRequest = permissionsList.filter {
            ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED
        }

        return if (permissionsToRequest.isNotEmpty()) {
            ActivityCompat.requestPermissions(
                this,
                permissionsToRequest.toTypedArray(),
                PERMISSION_REQUEST_CODE
            )
            false
        } else {
            true
        }
    }

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }
}
