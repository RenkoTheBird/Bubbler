package com.bubbler.android.data.model

import com.bubbler.android.core.network.ApiClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class StaffReportTest {
    private val json = ApiClient.defaultJson()

    @Test
    fun decodesStaffReportWithSnapshots() {
        val payload = """
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "reporter_id": 3,
              "post_id": "22222222-2222-2222-2222-222222222222",
              "reported_user_id": 9,
              "reason": "spam",
              "details": "looks automated",
              "status": "open",
              "content_snapshot": "Buy followers now",
              "topic_snapshot": "business",
              "author_username_snapshot": "spammer",
              "legal_hold": true,
              "created_at": "2026-08-20T14:30:00.000Z"
            }
        """.trimIndent()

        val report = json.decodeFromString(StaffReport.serializer(), payload)

        assertEquals(3, report.reporterId)
        assertEquals(9, report.reportedUserId)
        assertEquals(StaffReportStatus.OPEN, report.status)
        assertEquals("Buy followers now", report.contentSnapshot)
        assertEquals("Spam", report.reasonTitle)
        assertTrue(report.legalHold)
        assertEquals(Instant.parse("2026-08-20T14:30:00.000Z"), report.createdAt)
    }

    @Test
    fun userRoleMarksStaff() {
        val staff = User(
            id = 1,
            username = "mod",
            email = "mod@bubbler.test",
            role = "staff",
            createdAt = Instant.parse("2026-01-01T00:00:00Z"),
        )
        assertTrue(staff.isStaff)
        assertEquals("staff", staff.role)
    }
}
