package com.bubbler.android.features.report

import android.content.SharedPreferences
import com.bubbler.android.core.auth.TokenStore
import com.bubbler.android.core.network.ApiClient
import com.bubbler.android.core.network.ApiException
import com.bubbler.android.data.model.ReportReason
import com.bubbler.android.data.model.User
import com.bubbler.android.data.repository.BlocksRepository
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant

class ReportPostViewModelTest {
    @Test
    fun canSubmit_isFalseUntilReasonSelected() = runTest {
        val viewModel = ReportPostViewModel()
        assertFalse(viewModel.canSubmit)
        assertFalse(viewModel.submit())
        assertEquals("Choose a reason before submitting.", viewModel.errorMessage.value)
    }

    @Test
    fun canSubmit_isTrueWhenReasonSelected_withoutComments() = runTest {
        val viewModel = ReportPostViewModel()
        viewModel.selectReason(ReportReason.SPAM)
        assertTrue(viewModel.canSubmit)
        assertTrue(viewModel.submit())
        assertNull(viewModel.errorMessage.value)
    }

    @Test
    fun selectReason_clearsPreviousError() = runTest {
        val viewModel = ReportPostViewModel()
        viewModel.submit()
        viewModel.selectReason(ReportReason.HARASSMENT)
        assertNull(viewModel.errorMessage.value)
        assertEquals(ReportReason.HARASSMENT, viewModel.selectedReason.value)
    }

    @Test
    fun alsoBlockUser_defaultsOff_andDoesNotCallBlock() = runTest {
        val blocks = FakeBlocksRepository()
        val viewModel = ReportPostViewModel()
        viewModel.selectReason(ReportReason.SPAM)
        assertFalse(viewModel.alsoBlockUser.value)
        assertTrue(viewModel.submit(authorUsername = "troll", blocksRepository = blocks))
        assertTrue(blocks.blocked.isEmpty())
    }

    @Test
    fun submit_blocksAuthorWhenRequested() = runTest {
        val blocks = FakeBlocksRepository()
        val viewModel = ReportPostViewModel()
        viewModel.selectReason(ReportReason.HARASSMENT)
        viewModel.setAlsoBlockUser(true)
        assertTrue(viewModel.submit(authorUsername = "troll", blocksRepository = blocks))
        assertEquals(listOf("troll"), blocks.blocked)
        assertNull(viewModel.errorMessage.value)
    }

    @Test
    fun submit_blockWithoutUsername_showsError() = runTest {
        val blocks = FakeBlocksRepository()
        val viewModel = ReportPostViewModel()
        viewModel.selectReason(ReportReason.SPAM)
        viewModel.setAlsoBlockUser(true)
        assertFalse(viewModel.submit(authorUsername = null, blocksRepository = blocks))
        assertEquals("We couldn't block this user.", viewModel.errorMessage.value)
        assertTrue(blocks.blocked.isEmpty())
    }

    @Test
    fun submit_blockFailure_showsErrorAndKeepsForm() = runTest {
        val blocks = FakeBlocksRepository()
        blocks.failBlockWith = ApiException.ServerError(500, "boom")
        val viewModel = ReportPostViewModel()
        viewModel.selectReason(ReportReason.SPAM)
        viewModel.setAlsoBlockUser(true)
        assertFalse(viewModel.submit(authorUsername = "troll", blocksRepository = blocks))
        assertEquals("boom", viewModel.errorMessage.value)
        assertTrue(viewModel.canSubmit)
    }

    private class FakeBlocksRepository : BlocksRepository(
        apiClient = ApiClient(baseUrl = "http://localhost"),
        tokenStore = TokenStore(MemoryPrefs()),
    ) {
        val blocked = mutableListOf<String>()
        var failBlockWith: Exception? = null

        override suspend fun blockUser(username: String): User {
            failBlockWith?.let { throw it }
            blocked += username
            return User(
                id = 1,
                username = username,
                createdAt = Instant.parse("2026-08-03T12:00:00Z"),
                isBlocked = true,
            )
        }
    }

    private class MemoryPrefs : SharedPreferences {
        private val map = mutableMapOf<String, String?>()

        override fun getAll(): MutableMap<String, *> = map.toMutableMap()
        override fun getString(key: String?, defValue: String?): String? =
            if (map.containsKey(key)) map[key] else defValue
        override fun getStringSet(key: String?, defValues: MutableSet<String>?): MutableSet<String>? =
            defValues
        override fun getInt(key: String?, defValue: Int): Int = defValue
        override fun getLong(key: String?, defValue: Long): Long = defValue
        override fun getFloat(key: String?, defValue: Float): Float = defValue
        override fun getBoolean(key: String?, defValue: Boolean): Boolean = defValue
        override fun contains(key: String?): Boolean = map.containsKey(key)

        override fun edit(): SharedPreferences.Editor = object : SharedPreferences.Editor {
            private val pending = mutableMapOf<String, String?>()
            private val removals = mutableSetOf<String>()
            override fun putString(key: String?, value: String?): SharedPreferences.Editor {
                pending[key!!] = value
                return this
            }
            override fun putStringSet(key: String?, values: MutableSet<String>?) = this
            override fun putInt(key: String?, value: Int) = this
            override fun putLong(key: String?, value: Long) = this
            override fun putFloat(key: String?, value: Float) = this
            override fun putBoolean(key: String?, value: Boolean) = this
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
        }

        override fun registerOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
        override fun unregisterOnSharedPreferenceChangeListener(
            listener: SharedPreferences.OnSharedPreferenceChangeListener?,
        ) = Unit
    }
}
