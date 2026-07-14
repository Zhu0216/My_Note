package com.allinone.mynote

import android.content.Context
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "my_note/device_font"
    private val logTag = "MyNoteDeviceFont"

    private data class DeviceFont(
        val packageName: String,
        val displayName: String,
        val bytes: ByteArray,
    )

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "loadCurrentFont" -> result.success(loadCurrentFlipFont())
                    "loadFontCatalog" -> result.success(loadFontCatalog())
                    else -> result.notImplemented()
                }
            }
    }

    private fun loadCurrentFlipFont(): ByteArray? {
        val catalog = loadDeviceFontCatalog()
        val currentPackage = catalog["currentPackage"] as? String
        val fonts = catalog["fonts"] as? List<*>
        val currentFont = fonts
            ?.filterIsInstance<Map<String, Any>>()
            ?.firstOrNull { it["packageName"] == currentPackage }
        return currentFont?.get("bytes") as? ByteArray
    }

    private fun loadFontCatalog(): Map<String, Any?> {
        return loadDeviceFontCatalog()
    }

    private fun loadDeviceFontCatalog(): Map<String, Any?> {
        val flipFontStyle = readGlobalInt("flip_font_style", 0)
        val fontStyleIndex = readGlobalInt("font_style_index", -2)

        val packages = try {
            packageManager.getInstalledPackages(0)
        } catch (_: Exception) {
            emptyList()
        }
        val fontPackages = packages
            .map { it.packageName }
            .filter { it.startsWith("com.monotype.android.font.") }
        val candidates = fontPackages
            .distinct()
            .sortedWith(
                compareBy<String> { !isCustomSamsungFontPackage(it) }
                    .thenBy { it },
            )

        val selectedPackages = selectedFontPackages(
            flipFontStyle,
            fontStyleIndex,
            candidates,
        )
        Log.d(
            logTag,
            "Device font settings flip_font_style=$flipFontStyle " +
                "font_style_index=$fontStyleIndex candidates=$selectedPackages",
        )

        val fontsByPackage = linkedMapOf<String, DeviceFont>()
        for (packageName in selectedPackages) {
            val font = loadFlipFontFromPackage(packageName)
            if (font != null) {
                fontsByPackage[font.packageName] = font
            }
        }

        val currentPackage = fontsByPackage.keys.firstOrNull()
        val fonts = fontsByPackage.values.map {
            mapOf(
                "packageName" to it.packageName,
                "displayName" to it.displayName,
                "bytes" to it.bytes,
            )
        }
        if (currentPackage == null) {
            Log.d(logTag, "No Samsung FlipFont package could be loaded")
        } else {
            val currentFont = fontsByPackage.getValue(currentPackage)
            Log.d(
                logTag,
                "Loaded current device font ${currentFont.displayName} " +
                    "from $currentPackage (${currentFont.bytes.size} bytes)",
            )
        }
        return mapOf(
            "currentPackage" to currentPackage,
            "fonts" to fonts,
        )
    }

    private fun readGlobalInt(name: String, fallback: Int): Int {
        return try {
            Settings.Global.getInt(contentResolver, name, fallback)
        } catch (_: Exception) {
            fallback
        }
    }

    private fun selectedFontPackages(
        flipFontStyle: Int,
        fontStyleIndex: Int,
        installedFontPackages: List<String>,
    ): List<String> {
        val exactPackage = packageForBuiltInStyle(flipFontStyle)
            ?: packageForBuiltInStyle(fontStyleIndex)
        if (exactPackage != null) {
            return listOf(exactPackage) + installedFontPackages.filter { it != exactPackage }
        }

        val customPackages = installedFontPackages.filter(::isCustomSamsungFontPackage)
        if (customPackages.isNotEmpty() && (flipFontStyle > 0 || fontStyleIndex < 0)) {
            return customPackages + installedFontPackages.filter { it !in customPackages }
        }
        return installedFontPackages
    }

    private fun packageForBuiltInStyle(style: Int): String? {
        return when (style) {
            1 -> "com.monotype.android.font.samsungone"
            2 -> "com.monotype.android.font.roboto"
            3 -> "com.monotype.android.font.foundation"
            else -> null
        }
    }

    private fun isCustomSamsungFontPackage(packageName: String): Boolean {
        val normalized = packageName.lowercase()
        return !(
            normalized.endsWith(".samsungone") ||
                normalized.endsWith(".roboto") ||
                normalized.endsWith(".foundation")
            )
    }

    private fun loadFlipFontFromPackage(packageName: String): DeviceFont? {
        val fontContext = try {
            createPackageContext(packageName, Context.CONTEXT_IGNORE_SECURITY)
        } catch (_: Exception) {
            return null
        }
        val assets = fontContext.assets
        knownFontAssetForPackage(packageName)?.let { assetPath ->
            val bytes = try {
                assets.open(assetPath).use { it.readBytes() }
            } catch (_: Exception) {
                null
            }
            if (bytes != null && bytes.isNotEmpty()) {
                return DeviceFont(
                    packageName,
                    friendlyFontDisplayName(
                        packageName,
                        knownFontDisplayNameForPackage(packageName),
                    ),
                    bytes,
                )
            }
        }
        val xmlFiles = try {
            assets.list("xml")?.toList().orEmpty()
        } catch (_: Exception) {
            emptyList()
        }
        for (xmlFile in xmlFiles) {
            val fontMeta = try {
                assets.open("xml/$xmlFile").use { stream ->
                    val xml = stream.bufferedReader().readText()
                    val displayName = Regex("displayname=\"([^\"]+)\"")
                        .find(xml)
                        ?.groupValues
                        ?.getOrNull(1)
                        ?: knownFontDisplayNameForPackage(packageName)
                    val fileName = Regex("<filename>\\s*([^<]+?)\\s*</filename>")
                        .find(xml)
                        ?.groupValues
                        ?.getOrNull(1)
                    if (fileName.isNullOrBlank()) {
                        null
                    } else {
                        displayName to fileName
                    }
                }
            } catch (_: Exception) {
                null
            }
            if (fontMeta == null) {
                continue
            }
            val bytes = try {
                assets.open("fonts/${fontMeta.second}").use { it.readBytes() }
            } catch (_: Exception) {
                null
            }
            if (bytes != null && bytes.isNotEmpty()) {
                return DeviceFont(
                    packageName,
                    friendlyFontDisplayName(packageName, fontMeta.first),
                    bytes,
                )
            }
        }
        return null
    }

    private fun knownFontAssetForPackage(packageName: String): String? {
        return when (packageName.lowercase()) {
            "com.monotype.android.font.shaonv" -> "fonts/Shaonv.ttf"
            else -> null
        }
    }

    private fun knownFontDisplayNameForPackage(packageName: String): String {
        return when (packageName.lowercase()) {
            "com.monotype.android.font.shaonv" -> "少女體"
            "com.monotype.android.font.samsungone" -> "Samsung One"
            "com.monotype.android.font.roboto" -> "Roboto"
            "com.monotype.android.font.foundation" -> "Foundation"
            else -> packageName.substringAfterLast('.')
        }
    }

    private fun friendlyFontDisplayName(packageName: String, displayName: String): String {
        return when (packageName.lowercase()) {
            "com.monotype.android.font.shaonv" -> "少女體"
            "com.monotype.android.font.samsungone" -> "Samsung One"
            else -> displayName
        }
    }
}
