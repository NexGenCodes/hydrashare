package com.example.hydra_share

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.Context
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID

/// Bluetooth Handler for Android
class BluetoothHandler(private val context: Context) : MethodChannel.MethodCallHandler {
    private val bluetoothAdapter: BluetoothAdapter? = BluetoothAdapter.getDefaultAdapter()
    private val HYDRA_UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB") // SPP UUID
    private var connectedSocket: BluetoothSocket? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isBluetoothAvailable" -> {
                result.success(bluetoothAdapter != null && bluetoothAdapter.isEnabled)
            }
            "discoverBluetoothPeers" -> {
                discoverPeers(result)
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

    private fun discoverPeers(result: MethodChannel.Result) {
        if (bluetoothAdapter == null) {
            result.error("NOT_AVAILABLE", "Bluetooth not available", null)
            return
        }

        val pairedDevices = bluetoothAdapter.bondedDevices
        val devices = pairedDevices.map { device ->
            mapOf(
                "id" to device.address,
                "name" to (device.name ?: "Unknown"),
                "type" to "bluetooth"
            )
        }

        result.success(devices)
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
}
