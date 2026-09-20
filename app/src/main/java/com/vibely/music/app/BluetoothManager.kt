package com.vibely.music.app

import android.Manifest
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager as SystemBluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject

class BluetoothManager(private val context: Context) {

    private val adapter: BluetoothAdapter?
        get() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? SystemBluetoothManager)?.adapter

    private fun hasPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context, Manifest.permission.BLUETOOTH_CONNECT
        ) == PackageManager.PERMISSION_GRANTED
    }

    // Lista os dispositivos Bluetooth já emparelhados (colunas, auscultadores) — não requer
    // scan ativo, que exigiria localização em Android < 12 e é mais lento.
    fun listPairedDevices(): String {
        val arr = JSONArray()
        if (!hasPermission()) return arr.toString()
        val bonded: Set<BluetoothDevice> = try {
            adapter?.bondedDevices ?: emptySet()
        } catch (e: SecurityException) {
            emptySet()
        }
        for (device in bonded) {
            val name = try { device.name ?: "Dispositivo" } catch (e: SecurityException) { "Dispositivo" }
            val type = when {
                name.contains("tv", true) -> "tv"
                name.contains("speaker", true) || name.contains("boom", true) || name.contains("jbl", true) -> "speaker"
                else -> "headset"
            }
            arr.put(JSONObject().apply {
                put("id", device.address)
                put("name", name)
                put("type", type)
            })
        }
        return arr.toString()
    }

    fun isBluetoothEnabled(): Boolean = adapter?.isEnabled == true

    fun connect(deviceAddress: String): Boolean {
        // A ligação de áudio em si (perfil A2DP) é gerida pelo próprio sistema Android
        // assim que o dispositivo é selecionado nas definições de som — aqui confirmamos
        // apenas que o dispositivo é válido e está emparelhado.
        if (!hasPermission()) return false
        return try {
            adapter?.bondedDevices?.any { it.address == deviceAddress } == true
        } catch (e: SecurityException) {
            false
        }
    }
}