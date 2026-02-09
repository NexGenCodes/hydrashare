package com.example.hydra_share

import android.content.Context
import android.content.Intent
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.example.hydra_share.WiFiDirectHandler
import com.example.hydra_share.BluetoothHandler

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.hydrashare/p2p"

    private var wifiHandler: WiFiDirectHandler? = null
    private var bluetoothHandler: BluetoothHandler? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        wifiHandler = WiFiDirectHandler(this)
        bluetoothHandler = BluetoothHandler(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openP2PInvitation" -> {
                    openP2PInvitation()
                    result.success(true)
                }
                "startForegroundService" -> {
                    startDaemonService()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Register WiFi-Direct Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hydrashare/wifi_direct")
            .setMethodCallHandler(wifiHandler)

        // Register Bluetooth Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.hydrashare/bluetooth")
            .setMethodCallHandler(bluetoothHandler)
    }

    override fun onDestroy() {
        super.onDestroy()
        wifiHandler?.cleanup()
        bluetoothHandler?.cleanup()
    }

    private fun startDaemonService() {
        val intent = Intent(this, DaemonNativeService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun openP2PInvitation() {
        // Option 1: Open Wi-Fi Direct settings
        val intent = Intent(Settings.ACTION_WIFI_IP_SETTINGS)
        startActivity(intent)

        // Option 2: Actual P2P Discovery (if we wanted to do it in-app, but "system invitation" usually implies settings/system UI)
        val manager = getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
        val channel = manager?.initialize(this, mainLooper, null)
        manager?.discoverPeers(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                // Discovery started
            }
            override fun onFailure(reason: Int) {
                // Failed to start discovery
            }
        })
    }
}
