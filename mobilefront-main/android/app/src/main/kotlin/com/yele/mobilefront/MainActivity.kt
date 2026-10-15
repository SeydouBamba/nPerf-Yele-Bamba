package com.yele.mobilefront

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.location.Geocoder
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.TrafficStats
import android.net.wifi.WifiManager
import android.os.Build
import android.os.Process
import android.telephony.CellInfo
import android.telephony.CellSignalStrengthLte
import android.telephony.CellSignalStrengthNr
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import java.util.Locale
import java.util.concurrent.Executors
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.yele/telephony"
    private val phonePermissionRequestCode = 1001
    private val notificationPermissionRequestCode = 1002
    private val geocoderExecutor = Executors.newSingleThreadExecutor()

    override fun onDestroy() {
        geocoderExecutor.shutdownNow()
        super.onDestroy()
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getTelephony" -> result.success(telephonyInfo())
                    "getConnection" -> result.success(connectionInfo())
                    "getPermissionStatuses" -> result.success(permissionStatuses())
                    "reverseGeocode" -> {
                        val latitude = call.argument<Double>("latitude")
                        val longitude = call.argument<Double>("longitude")
                        if (latitude == null || longitude == null) {
                            result.error("invalid_coordinates", "Coordonnées GPS manquantes", null)
                        } else {
                            reverseGeocode(latitude, longitude, result)
                        }
                    }
                    "requestPhonePermission" -> result.success(ensurePhonePermission())
                    "getRxBytes" -> result.success(rxBytes())
                    "getTxBytes" -> result.success(txBytes())
                    "startCollect" -> {
                        val interval = call.argument<Int>("intervalMinutes")
                            ?: SignalCollectorService.DEFAULT_INTERVAL_MIN
                        val apiBase = call.argument<String>("apiBaseUrl")
                        result.success(startCollect(interval, apiBase))
                    }
                    "stopCollect" -> {
                        stopCollect()
                        result.success(true)
                    }
                    "getCollectStatus" -> result.success(collectStatus())
                    else -> result.notImplemented()
                }
            }
    }

    /// Retourne true si READ_PHONE_STATE est déjà accordée ; sinon déclenche la
    /// demande runtime (le résultat sera disponible aux prochaines lectures).
    private fun ensurePhonePermission(): Boolean {
        val granted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.READ_PHONE_STATE), phonePermissionRequestCode
            )
        }
        return granted
    }

    private fun permissionStatuses(): Map<String, Boolean> {
        val phoneGranted = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_PHONE_STATE
        ) == PackageManager.PERMISSION_GRANTED
        val notificationsGranted = Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        return mapOf(
            "phone" to phoneGranted,
            "notifications" to notificationsGranted,
        )
    }

    @Suppress("DEPRECATION")
    private fun reverseGeocode(
        latitude: Double,
        longitude: Double,
        result: MethodChannel.Result,
    ) {
        geocoderExecutor.execute {
            val address = try {
                Geocoder(this, Locale.getDefault())
                    .getFromLocation(latitude, longitude, 1)
                    ?.firstOrNull()
                    ?.getAddressLine(0)
                    ?.takeIf { it.isNotBlank() }
            } catch (error: Exception) {
                android.util.Log.w("Yele", "Reverse geocoding unavailable", error)
                null
            }
            runOnUiThread { result.success(address) }
        }
    }

    /// Octets reçus par l'application depuis le démarrage de l'appareil, ou -1
    /// si l'appareil ne tient pas ce compteur. Inclut le trafic du WebView : la
    /// pile réseau de Chromium tourne dans le processus de l'app, donc sous le
    /// même UID.
    private fun rxBytes(): Long {
        val bytes = TrafficStats.getUidRxBytes(Process.myUid())
        return if (bytes == TrafficStats.UNSUPPORTED.toLong()) -1L else bytes
    }

    /// Octets émis par l'application depuis le démarrage de l'appareil, ou -1
    /// si le compteur n'est pas tenu. Complète [rxBytes] : un test de débit
    /// consomme surtout en réception, mais la phase d'upload émet réellement des
    /// données — la consommation totale d'un test est donc rx + tx.
    private fun txBytes(): Long {
        val bytes = TrafficStats.getUidTxBytes(Process.myUid())
        return if (bytes == TrafficStats.UNSUPPORTED.toLong()) -1L else bytes
    }

    // ── Collecte passive en arrière-plan ────────────────────────────────────

    /// Démarre le service de collecte. Retourne false si la notification est
    /// refusée : sans elle, Android tue immédiatement un service de premier
    /// plan, et la collecte s'arrêterait sans que l'utilisateur comprenne.
    private fun startCollect(intervalMinutes: Int, apiBaseUrl: String?): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.POST_NOTIFICATIONS
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                this, arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                notificationPermissionRequestCode,
            )
            return false
        }

        SignalCollectorService.prefs(this).edit()
            .putInt(SignalCollectorService.KEY_INTERVAL, intervalMinutes)
            .apply {
                if (apiBaseUrl != null) {
                    putString(SignalCollectorService.KEY_API_BASE, apiBaseUrl)
                }
            }
            .apply()

        val intent = Intent(this, SignalCollectorService::class.java)
            .setAction(SignalCollectorService.ACTION_START)
        ContextCompat.startForegroundService(this, intent)
        return true
    }

    private fun stopCollect() {
        val intent = Intent(this, SignalCollectorService::class.java)
            .setAction(SignalCollectorService.ACTION_STOP)
        try {
            startService(intent)
        } catch (e: Exception) {
            // Service déjà arrêté : on met simplement l'état à jour.
            SignalCollectorService.prefs(this).edit()
                .putBoolean(SignalCollectorService.KEY_ENABLED, false).apply()
        }
    }

    /// Retourne { running, intervalMinutes, lastCollectAt, count }.
    private fun collectStatus(): Map<String, Any?> {
        val p = SignalCollectorService.prefs(this)
        return mapOf(
            "running" to SignalCollectorService.isRunning,
            "enabled" to p.getBoolean(SignalCollectorService.KEY_ENABLED, false),
            "intervalMinutes" to p.getInt(
                SignalCollectorService.KEY_INTERVAL,
                SignalCollectorService.DEFAULT_INTERVAL_MIN,
            ),
            "lastCollectAt" to p.getLong(SignalCollectorService.KEY_LAST_AT, 0L),
            "count" to p.getInt(SignalCollectorService.KEY_COUNT, 0),
        )
    }

    /// Retourne { connectionType, wifiSsid, wifiBand } : par où passe
    /// **réellement** Internet à cet instant (ISS-03). On interroge le réseau
    /// par défaut (`activeNetwork`), car la liste des transports actifs ne
    /// permet pas de trancher quand le WiFi et la data mobile sont tous deux
    /// allumés. Les champs Wi-Fi restent null hors WiFi ou si l'OS les masque.
    private fun connectionInfo(): Map<String, Any?> {
        val info = HashMap<String, Any?>()
        info["connectionType"] = null
        info["wifiSsid"] = null
        info["wifiBand"] = null
        info["locationEnabled"] = null

        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
            ?: return info

        val caps = try {
            cm.activeNetwork?.let { cm.getNetworkCapabilities(it) }
        } catch (_: Exception) {
            null
        } ?: return info

        // Un VPN n'est pas un transport en soi : sans transport identifiable on
        // renvoie null et Dart retombe sur connectivity_plus.
        val type = when {
            caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "WiFi"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "Ethernet"
            caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "Mobile"
            else -> null
        } ?: return info
        info["connectionType"] = type

        if (type == "WiFi") {
            val (ssid, band) = wifiDetails()
            info["wifiSsid"] = ssid
            info["wifiBand"] = band
        }
        info["locationEnabled"] = locationEnabled()
        return info
    }

    /// Vrai si la localisation système est activée. Android masque le SSID des
    /// réseaux WiFi aux applications tant qu'elle ne l'est pas : sans cette
    /// information, l'interface ne pourrait pas expliquer un nom manquant.
    private fun locationEnabled(): Boolean? {
        return try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                ?: return null
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                lm.isLocationEnabled
            } else {
                lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) ||
                    lm.isProviderEnabled(LocationManager.GPS_PROVIDER)
            }
        } catch (_: Exception) {
            null
        }
    }

    /// SSID et bande du point d'accès connecté, ou (null, null) si l'OS ne les
    /// expose pas. Depuis Android 8.1 le SSID est masqué (« unknown ssid »)
    /// quand la localisation n'est pas accordée : on renvoie null plutôt qu'un
    /// faux nom, l'interface affichant alors « — ».
    private fun wifiDetails(): Pair<String?, String?> {
        val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            ?: return null to null
        val w = try {
            wm.connectionInfo
        } catch (_: Exception) {
            null
        } ?: return null to null

        val raw = w.ssid?.trim().orEmpty().removeSurrounding("\"")
        // Android renvoie « <unknown ssid> » (ou « 0x… ») quand il se refuse à
        // livrer le nom : on renvoie null, que l'interface sait expliquer.
        val ssid = raw.takeIf {
            it.isNotEmpty() &&
                !it.contains("unknown ssid", ignoreCase = true) &&
                !it.startsWith("0x")
        }

        // La bande explique une bonne part des écarts de débit entre deux
        // mesures faites sur le même SSID (2,4 GHz vs 5 GHz).
        val band = when (w.frequency) {
            in 2400..2500 -> "2,4 GHz"
            in 4900..5895 -> "5 GHz"
            in 5925..7125 -> "6 GHz"
            else -> null
        }
        return ssid to band
    }

    /// Retourne { simOperator, mccMnc, operatorCode, cellularTech,
    /// dataSimSlot, simCount, rsrp, rsrq } — champs null si indisponible.
    private fun telephonyInfo(): Map<String, Any?> {
        val info = HashMap<String, Any?>()
        info["simOperator"] = null
        info["mccMnc"] = null
        info["operatorCode"] = null
        info["cellularTech"] = null
        info["dataSimSlot"] = null
        info["simCount"] = 0
        info["rsrp"] = null
        info["rsrq"] = null

        val base = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager ?: return info

        // ISS-02 : sur un téléphone bi-SIM, `getSystemService` renvoie le
        // TelephonyManager par défaut (SIM 1), qui décrit l'abonnement de
        // secours et non celui utilisé pour les données. On résout l'abonnement
        // data actif, puis on fabrique un TelephonyManager lié à cet
        // abonnement : opérateur, techno et signal décrivent alors réellement
        // la SIM qui porte le test.
        val tm = telephonyForActiveData(base)

        // Emplacement (0-indexé) de la SIM data + nombre de SIM actives :
        // permet à l'interface d'afficher « SIM 2 » et de lever toute ambiguïté.
        val (slot, count) = dataSimInfo()
        if (slot != null) info["dataSimSlot"] = slot
        info["simCount"] = count

        try {
            // Nom de l'opérateur du réseau mobile (SIM enregistrée sur le réseau).
            val name = tm.networkOperatorName?.trim()
            if (!name.isNullOrEmpty()) info["simOperator"] = name

            // MCC+MNC (ex. "61301") — permet un mapping fiable côté Dart.
            val mccMnc = tm.networkOperator?.trim()
            if (!mccMnc.isNullOrEmpty()) info["mccMnc"] = mccMnc
            // Code brut conservé : il distingue l'agrégation LTE (suffixe '04',
            // cf. dataNetworkType) et permet d'afficher « Moov Africa (613:10) »
            // comme nPerf.
            info["operatorCode"] = mccMnc
        } catch (e: SecurityException) {
            // Permission manquante : on laisse simOperator/mccMnc à null.
        } catch (e: Exception) {
            // Ignorer toute erreur constructeur.
        }

        // Techno radio : nécessite READ_PHONE_STATE sur Android 10+.
        try {
            @Suppress("DEPRECATION")
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                tm.dataNetworkType
            } else {
                tm.networkType
            }
            info["cellularTech"] = techLabel(type)
        } catch (e: SecurityException) {
            // Permission manquante : techno inconnue.
        } catch (e: Exception) {
            // Ignorer.
        }

        // ISS-01 : RSRP (puissance) et RSRQ (qualité) de la cellule servante,
        // lus sur l'abonnement data actif. API 29+ uniquement.
        val (rsrp, rsrq) = readRadioSignal(tm)
        info["rsrp"] = rsrp
        info["rsrq"] = rsrq

        return info
    }

    /// TelephonyManager rattaché à l'abonnement data actif, ou [base] en repli
    /// (API trop ancienne, ou identifiant d'abonnement introuvable).
    private fun telephonyForActiveData(base: TelephonyManager): TelephonyManager {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return base
        return try {
            val subId = SubscriptionManager.getDefaultDataSubscriptionId()
            if (subId == SubscriptionManager.INVALID_SUBSCRIPTION_ID) base
            else base.createForSubscriptionId(subId)
        } catch (_: Exception) {
            base
        }
    }

    /// Emplacement 0-indexé de la SIM data et nombre de SIM actives.
    private fun dataSimInfo(): Pair<Int?, Int> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return null to 0
        return try {
            val sm = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE)
                as? SubscriptionManager ?: return null to 0
            val subId = SubscriptionManager.getDefaultDataSubscriptionId()
            val slot = if (subId != SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
                sm.getActiveSubscriptionInfo(subId)?.simSlotIndex
            } else null
            slot to sm.activeSubscriptionInfoCount
        } catch (_: Exception) {
            null to 0
        }
    }

    /// RSRP (dBm) et RSRQ (dB) de la cellule servante, ou (null, null) si
    /// l'information n'est pas exposée. Les valeurs « indisponibles » du
    /// framework ([CellInfo.UNAVAILABLE], soit Int.MAX_VALUE) sont écartées.
    private fun readRadioSignal(tm: TelephonyManager): Pair<Int?, Int?> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null to null
        return try {
            val strengths = tm.signalStrength?.cellSignalStrengths ?: return null to null
            for (s in strengths) {
                when (s) {
                    is CellSignalStrengthLte -> {
                        if (isValidRsrp(s.rsrp)) {
                            return s.rsrp to s.rsrq.takeIf { isValidRsrq(it) }
                        }
                    }

                    is CellSignalStrengthNr -> {
                        if (isValidRsrp(s.ssRsrp)) {
                            return s.ssRsrp to s.ssRsrq.takeIf { isValidRsrq(it) }
                        }
                    }
                }
            }
            null to null
        } catch (_: Exception) {
            null to null
        }
    }

    /// Un RSRP exploitable est négatif (typiquement -44 à -140 dBm).
    private fun isValidRsrp(v: Int): Boolean = v != CellInfo.UNAVAILABLE && v in -160..-30

    /// Un RSRQ exploitable est négatif (typiquement -3 à -20 dB).
    private fun isValidRsrq(v: Int): Boolean = v != CellInfo.UNAVAILABLE && v in -40..0

    private fun techLabel(type: Int): String? {
        return when (type) {
            TelephonyManager.NETWORK_TYPE_GPRS,
            TelephonyManager.NETWORK_TYPE_EDGE,
            TelephonyManager.NETWORK_TYPE_CDMA,
            TelephonyManager.NETWORK_TYPE_1xRTT,
            TelephonyManager.NETWORK_TYPE_IDEN,
            TelephonyManager.NETWORK_TYPE_GSM -> "2G"

            TelephonyManager.NETWORK_TYPE_UMTS,
            TelephonyManager.NETWORK_TYPE_EVDO_0,
            TelephonyManager.NETWORK_TYPE_EVDO_A,
            TelephonyManager.NETWORK_TYPE_HSDPA,
            TelephonyManager.NETWORK_TYPE_HSUPA,
            TelephonyManager.NETWORK_TYPE_HSPA,
            TelephonyManager.NETWORK_TYPE_EVDO_B,
            TelephonyManager.NETWORK_TYPE_EHRPD,
            TelephonyManager.NETWORK_TYPE_HSPAP,
            TelephonyManager.NETWORK_TYPE_TD_SCDMA -> "3G"

            // 4G+ : agrégation de porteuses LTE (LTE-A), libellé nPerf.
            // 19 = TelephonyManager.NETWORK_TYPE_LTE_CA (API 29+) — constante
            // inlinée : le compileSdk du build ne l'expose pas symboliquement.
            19 -> "4G+"

            TelephonyManager.NETWORK_TYPE_LTE,
            TelephonyManager.NETWORK_TYPE_IWLAN -> "4G"

            TelephonyManager.NETWORK_TYPE_NR -> "5G"

            else -> null
        }
    }
}
