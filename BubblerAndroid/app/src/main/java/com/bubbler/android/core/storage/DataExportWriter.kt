package com.bubbler.android.core.storage

import android.content.ContentResolver
import android.net.Uri
import java.io.IOException
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter

/**
 * Writes account export zip bytes to a user-chosen SAF document URI.
 * Mirrors iOS [DataExportFileStore] filename conventions; Android saves via
 * Create Document instead of a temp file + share sheet.
 */
object DataExportWriter {
    private val fileNameFormatter: DateTimeFormatter =
        DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HHmmss'Z'")
            .withZone(ZoneOffset.UTC)

    fun suggestedFileName(createdAt: Instant = Instant.now()): String =
        "bubbler-export-${fileNameFormatter.format(createdAt)}.zip"

    fun writeZip(contentResolver: ContentResolver, uri: Uri, data: ByteArray) {
        val stream = contentResolver.openOutputStream(uri)
            ?: throw IOException("Could not open the chosen save location.")
        stream.use { output ->
            output.write(data)
            output.flush()
        }
    }
}
