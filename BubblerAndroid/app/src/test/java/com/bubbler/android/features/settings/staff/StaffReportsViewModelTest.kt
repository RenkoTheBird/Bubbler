package com.bubbler.android.features.settings.staff

import android.content.SharedPreferences
import com.bubbler.android.core.auth.AuthSession
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.StaffReport
import com.bubbler.android.data.model.StaffReportReasonFilter
import com.bubbler.android.data.model.StaffReportStatus
import com.bubbler.android.data.repository.AuthRepository
import com.bubbler.android.data.repository.StaffReportsRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import java.time.Instant
import java.util.Base64

class StaffReportsViewModelTest {
    private lateinit var repository: FakeStaffReportsRepository
    private lateinit var viewModel: StaffReportsViewModel

    @Before
    fun setUp() {
        repository = FakeStaffReportsRepository()
        viewModel = StaffReportsViewModel(
            authSession = signedInSession(7),
            staffReportsRepository = repository,
        )
    }

    @Test
    fun loadReports_fetchesOpenQueue() = runTest {
        repository.reports = listOf(staffReport(status = StaffReportStatus.OPEN))

        viewModel.loadReportsAwait()

        assertEquals(1, viewModel.reports.value.size)
        assertEquals(StaffReportStatus.OPEN, repository.lastListedStatus)
        assertEquals(StaffReportReasonFilter.ALL, repository.lastListedReason)
        assertEquals(null, viewModel.errorMessage.value)
    }

    @Test
    fun changeStatusFilter_requestsSelectedStatus() = runTest {
        repository.reports = emptyList()

        viewModel.changeStatusFilterAwait(StaffReportStatus.IN_REVIEW)

        assertEquals(StaffReportStatus.IN_REVIEW, viewModel.selectedStatus.value)
        assertEquals(StaffReportStatus.IN_REVIEW, repository.lastListedStatus)
    }

    @Test
    fun changeReasonFilter_isolatesIllegalBucket() = runTest {
        repository.reports = emptyList()

        viewModel.changeReasonFilterAwait(StaffReportReasonFilter.ILLEGAL_CONTENT)

        assertEquals(StaffReportReasonFilter.ILLEGAL_CONTENT, viewModel.selectedReason.value)
        assertEquals(StaffReportReasonFilter.ILLEGAL_CONTENT, repository.lastListedReason)
    }

    @Test
    fun loadReports_surfacesServerError() = runTest {
        repository.listError = ApiException.ServerError(403, "Staff access required")

        viewModel.loadReportsAwait()

        assertEquals("Staff access required", viewModel.errorMessage.value)
        assertTrue(viewModel.reports.value.isEmpty())
    }

    private fun staffReport(
        status: StaffReportStatus = StaffReportStatus.OPEN,
    ) = StaffReport(
        id = "11111111-1111-1111-1111-111111111111",
        reporterId = 3,
        postId = "22222222-2222-2222-2222-222222222222",
        reportedUserId = 9,
        reason = "spam",
        details = null,
        status = status,
        contentSnapshot = "Buy followers now",
        topicSnapshot = "business",
        authorUsernameSnapshot = "spammer",
        createdAt = Instant.parse("2026-08-20T14:30:00Z"),
    )

    private fun signedInSession(userId: Int): AuthSession {
        val store = TokenStore(MemoryPrefs())
        store.saveAccessToken(jwtForUser(userId))
        return AuthSession(
            tokenStore = store,
            authRepository = AuthRepository(ApiClient(baseUrl = "http://localhost")),
        )
    }

    private fun jwtForUser(userId: Int): String {
        val header = Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"alg":"none"}""".toByteArray())
        val payload = Base64.getUrlEncoder().withoutPadding()
            .encodeToString("""{"sub":"$userId"}""".toByteArray())
        return "$header.$payload.sig"
    }

    private class FakeStaffReportsRepository : StaffReportsRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        var reports: List<StaffReport> = emptyList()
        var listError: Exception? = null
        var lastListedStatus: StaffReportStatus? = null
        var lastListedReason: StaffReportReasonFilter? = null

        override suspend fun listReports(
            status: StaffReportStatus,
            reason: StaffReportReasonFilter,
        ): List<StaffReport> {
            lastListedStatus = status
            lastListedReason = reason
            listError?.let { throw it }
            return reports
        }
    }

    private class MemoryPrefs : SharedPreferences {
        private val map = mutableMapOf<String, String?>()

        override fun getString(key: String?, defValue: String?): String? =
            if (map.containsKey(key)) map[key] else defValue

        override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
            private val pending = mutableMapOf<String, String?>()
            private val removals = mutableSetOf<String>()

            override fun putString(key: String?, value: String?): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }

            override fun remove(key: String?): SharedPreferences.Editor {
                removals.add(key!!)
                return this
            }

            override fun clear(): SharedPreferences.Editor {
                map.clear()
                return this
            }

            override fun commit(): Boolean {
                removals.forEach { map.remove(it) }
                map.putAll(pending)
                pending.clear()
                removals.clear()
                return true
            }

            override fun apply() {
                commit()
            }

            override fun putStringSet(key: String?, values: MutableSet<String>?) = this
            override fun putInt(key: String?, value: Int) = this
            override fun putLong(key: String?, value: Long) = this
            override fun putFloat(key: String?, value: Float) = this
            override fun putBoolean(key: String?, value: Boolean) = this
        }

        override fun getAll(): MutableMap<String, *> = map.toMutableMap()
        override fun getStringSet(key: String?, defValues: MutableSet<String>?) = defValues
        override fun getInt(key: String?, defValue: Int) = defValue
        override fun getLong(key: String?, defValue: Long) = defValue
        override fun getFloat(key: String?, defValue: Float) = defValue
        override fun getBoolean(key: String?, defValue: Boolean) = defValue
        override fun contains(key: String?) = map.containsKey(key)
        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }
}
