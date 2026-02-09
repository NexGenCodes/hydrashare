package com.example.hydra_share

import android.content.Context
import android.content.Intent
import android.net.wifi.p2p.WifiP2pConfig
import android.net.wifi.p2p.WifiP2pDevice
import android.net.wifi.p2p.WifiP2pManager
import android.os.Looper
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/// WiFi-Direct Handler for Android
class WiFiDirectHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    private var wifiP2pManager: WifiP2pManager? = null
    private var channel: WifiP2pManager.Channel? = null
    private val peers = mutableListOf<WifiP2pDevice>()

    init {
        wifiP2pManager = context.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
        channel = wifiP2pManager?.initialize(context, Looper.getMainLooper(), null)
    }
    private val receiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            if (WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION == action) {
                wifiP2pManager?.requestPeers(channel) { peerList ->
                    peers.clear()
                    peers.addAll(peerList.deviceList)
                }
            }
        }
    }

    private var isReceiverRegistered = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startWiFiDirectDiscovery" -> {
                if (!isReceiverRegistered) {
                    val intentFilter = android.content.IntentFilter().apply {
                        addAction(WifiP2pManager.WIFI_P2P_PEERS_CHANGED_ACTION)
                    }
                    context.registerReceiver(receiver, intentFilter)
                    isReceiverRegistered = true
                }
                discoverPeers(result)
            }
            "getWiFiDirectPeers" -> {
                val peerList = peers.map { device ->
                    mapOf(
                        "id" to device.deviceAddress,
                        "name" to (device.deviceName ?: "Unknown"),
                        "type" to "wifi-direct",
                        "status" to device.status
                    )
                }
                result.success(peerList)
            }
            "connectWiFiDirect" -> {
                val peerId = call.argument<String>("peerId")
                if (peerId != null) {
                    connectToPeer(peerId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "peerId is required", null)
                }
            }
            "isWiFiDirectAvailable" -> {
                result.success(wifiP2pManager != null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun discoverPeers(result: MethodChannel.Result) {
        wifiP2pManager?.discoverPeers(channel, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                result.success(true)
            }

            override fun onFailure(reasonCode: Int) {
                result.error("DISCOVERY_FAILED", "Code: $reasonCode", null)
            }
        })
    }

    private fun connectToPeer(peerId: String, result: MethodChannel.Result) {
        val device = peers.find { it.deviceAddress == peerId }
        if (device == null) {
            result.error("PEER_NOT_FOUND", "Peer $peerId not discovered", null)
            return
        }

        val config = WifiP2pConfig().apply {
            deviceAddress = device.deviceAddress
        }

        wifiP2pManager?.connect(channel, config, object : WifiP2pManager.ActionListener {
            override fun onSuccess() {
                result.success(true)
            }

            override fun onFailure(reasonCode: Int) {
                result.error("CONNECTION_FAILED", "Code: $reasonCode", null)
            }
        })
    }
    fun cleanup() {
        if (isReceiverRegistered) {
            try {
                context.unregisterReceiver(receiver)
            } catch (e: Exception) {
                // Ignore
            }
            isReceiverRegistered = false
        }
    }
}
