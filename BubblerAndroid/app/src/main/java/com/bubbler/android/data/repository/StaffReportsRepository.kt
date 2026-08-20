package com.bubbler.android.data.repository

import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.Endpoints
import com.bubbler.android.data.model.StaffReport
import com.bubbler.android.data.model.StaffReportReasonFilter
import com.bubbler.android.data.model.StaffReportStatus
import com.bubbler.android.data.model.StaffReportStatusUpdateBody
import okhttp3.RequestBody.Companion.toRequestBody

/** Staff report queue — list / get / triage (`/admin/reports`). */
open class StaffReportsRepository(
    private val apiClient: ApiClient,
    private val tokenStore: TokenStore,
) {
    open suspend fun listReports(
        status: StaffReportStatus = StaffReportStatus.OPEN,
        reason: StaffReportReasonFilter = StaffReportReasonFilter.ALL,
    ): List<StaffReport> =
        apiClient.get(
            Endpoints.adminReports(status.apiValue, reason.apiValue),
            token = tokenStore.requireAccessToken(),
        )

    open suspend fun getReport(reportId: String): StaffReport =
        apiClient.get(
            Endpoints.adminReport(reportId),
            token = tokenStore.requireAccessToken(),
        )

    open suspend fun updateStatus(
        reportId: String,
        status: StaffReportStatus,
    ): StaffReport {
        val payload = apiClient.json.encodeToString(
            StaffReportStatusUpdateBody.serializer(),
            StaffReportStatusUpdateBody(status = status.apiValue),
        )
        return apiClient.request(
            path = Endpoints.adminReport(reportId),
            method = "PATCH",
            token = tokenStore.requireAccessToken(),
            body = payload.toRequestBody(ApiClient.JSON_MEDIA_TYPE),
            contentType = "application/json",
        )
    }
}
