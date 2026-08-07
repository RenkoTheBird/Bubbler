package com.bubbler.android.core.storage

import android.content.ContentResolver
import android.net.Uri
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import java.io.IOException
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * Pretty-prints account export JSON and writes it to a user-chosen SAF document URI.
 * Mirrors iOS [DataExportFileStore] filename conventions.
 */
object DataExportWriter {
    private val fileNameFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HHmmss'Z'")
            .withZone(ZoneOffset.UTC)

    private val prettyJson = Json {
        prettyPrint = true
        prettyPrintIndent = "  "
    }

    fun suggestedFileName(createdAt: Instant = Instant.now()): String =
        "bubbler-export-${fileNameFormatter.format(createdAt)}.json"

    /** Re-encodes compact API JSON as pretty-printed UTF-8 bytes. */
    fun prettyPrintJson(raw: String): ByteArray {
        val element = Json.parseToJsonElement(raw)
        return prettyJson.encodeToString(JsonElement.serializer(), element)
            .toByteArray(Charsets.UTF_8)
    }

    fun writeJson(contentResolver: ContentResolver, uri: Uri, data: ByteArray) {
        val stream = contentResolver.openOutputStream(uri)
            ?: throw IOException("Could not open the chosen save location.")
        stream.use { output ->
            output.write(data)
            output.flush()
        }
    }
}
