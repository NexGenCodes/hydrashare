package com.example.hydra_share

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID

/// Bluetooth Handler for Android
class BluetoothHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private val HYDRA_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // SPP UUID
    private var connectedSocket: BluetoothSocket? = null

    private val discoveredDevices = mutableListOf<BluetoothDevice>()

    private val receiver = object : android.content.BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val action = intent.action
            if (BluetoothDevice.ACTION_FOUND == action) {
                val device: BluetoothDevice? = intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                if (device != null) {
                    val alreadyExists = discoveredDevices.any { it.address == device.address }
                    if (!alreadyExists) {
                        discoveredDevices.add(device)
                    }
                }
            }
        }
    }

    private var isReceiverRegistered = false

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startBluetoothDiscovery" -> {
                if (bluetoothAdapter == null) {
                    result.error("NOT_AVAILABLE", "Bluetooth not available", null)
                    return
                }
                if (!isReceiverRegistered) {
                    val filter = android.content.IntentFilter(BluetoothDevice.ACTION_FOUND)
                    context.registerReceiver(receiver, filter)
                    isReceiverRegistered = true
                }
                bluetoothAdapter.startDiscovery()
                result.success(true)
            }
            "getBluetoothPeers" -> {
               val pairedDevices = bluetoothAdapter?.bondedDevices ?: emptySet()
               val allDevices = (pairedDevices + discoveredDevices).distinctBy { it.address }
               
               val mappedDevices = allDevices.map { device ->
                    mapOf(
                        "id" to device.address,
                        "name" to (device.name ?: "Unknown"),
                        "type" to "bluetooth"
                    )
               }
               result.success(mappedDevices)
            }
            "isBluetoothAvailable" -> {
                result.success(bluetoothAdapter != null && bluetoothAdapter.isEnabled)
            }
            "connectBluetooth" -> {
                val peerId = call.argument<String>("peerId")
                if (peerId != null) {
                    connectToPeer(peerId, result)
                } else {
                    result.error("INVALID_ARGUMENT", "peerId is required", null)
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun connectToPeer(peerId: String, result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("NOT_AVAILABLE", "Bluetooth not available", null)
            return
        }

        val device: BluetoothDevice? = bluetoothAdapter.getRemoteDevice(peerId)
        if (device == null) {
            result.error("PEER_NOT_FOUND", "Device $peerId not found", null)
            return
        }

        Thread {
            try {
                val socket = device.createRfcommSocketToServiceRecord(HYDRA_UUID)
                bluetoothAdapter.cancelDiscovery()
                socket.connect()
                connectedSocket = socket
                result.success(true)
            } catch (e: IOException) {
                result.error("CONNECTION_FAILED", e.message, null)
            }
        }.start()
    }

    fun disconnect() {
        try {
            connectedSocket?.close()
            connectedSocket = null
        } catch (e: IOException) {
            // Ignore
        }
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
        disconnect()
    }
}
