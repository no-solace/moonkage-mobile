package edu.fpt.moonkage.mobile

import android.app.PendingIntent
import android.content.Intent
import android.content.IntentFilter
import android.nfc.NfcAdapter
import android.nfc.tech.Ndef
import android.nfc.tech.NfcA
import android.nfc.tech.NfcB
import android.nfc.tech.NfcF
import android.nfc.tech.NfcV
import android.os.Build
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    private var nfcAdapter: NfcAdapter? = null
    private var pendingIntent: PendingIntent? = null
    private var intentFiltersArray: Array<IntentFilter>? = null
    private var techListsArray: Array<Array<String>>? = null

    override fun onResume() {
        super.onResume()
        // Kích hoạt Foreground Dispatch: Bắt buộc Android chuyển thẳng mọi thẻ NFC
        // vào app qua onNewIntent, tuyệt đối không được gọi Tag Viewer mặc định của hệ thống.
        enableForegroundDispatch()
    }

    override fun onPause() {
        super.onPause()
        disableForegroundDispatch()
    }

    private fun enableForegroundDispatch() {
        if (nfcAdapter == null) {
            nfcAdapter = NfcAdapter.getDefaultAdapter(this)
        }
        val adapter = nfcAdapter ?: return

        if (pendingIntent == null) {
            val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            pendingIntent = PendingIntent.getActivity(this, 0, intent, flags)

            val ndefFilter = IntentFilter(NfcAdapter.ACTION_NDEF_DISCOVERED).apply {
                try {
                    addDataType("*/*")
                } catch (_: IntentFilter.MalformedMimeTypeException) {}
            }
            val tagFilter = IntentFilter(NfcAdapter.ACTION_TAG_DISCOVERED)
            val techFilter = IntentFilter(NfcAdapter.ACTION_TECH_DISCOVERED)
            intentFiltersArray = arrayOf(ndefFilter, tagFilter, techFilter)

            techListsArray = arrayOf(
                arrayOf(NfcA::class.java.name),
                arrayOf(NfcB::class.java.name),
                arrayOf(NfcF::class.java.name),
                arrayOf(NfcV::class.java.name),
                arrayOf(Ndef::class.java.name)
            )
        }

        try {
            adapter.enableForegroundDispatch(this, pendingIntent, intentFiltersArray, techListsArray)
        } catch (_: Exception) {
            // Bỏ qua nếu thiết bị không hỗ trợ NFC
        }
    }

    private fun disableForegroundDispatch() {
        try {
            nfcAdapter?.disableForegroundDispatch(this)
        } catch (_: Exception) {}
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Nuốt toàn bộ Intent NFC do ForegroundDispatch bắt được, không cho OS mở Tag Viewer
    }
}
