package com.bubbler.android.features.report

import com.bubbler.android.data.model.ReportReason
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ReportPostViewModelTest {
    @Test
    fun canSubmit_isFalseUntilReasonSelected() {
        val viewModel = ReportPostViewModel()
        assertFalse(viewModel.canSubmit)
        assertFalse(viewModel.submit())
        assertEquals("Choose a reason before submitting.", viewModel.errorMessage.value)
    }

    @Test
    fun canSubmit_isTrueWhenReasonSelected_withoutComments() {
        val viewModel = ReportPostViewModel()
        viewModel.selectReason(ReportReason.SPAM)
        assertTrue(viewModel.canSubmit)
        assertTrue(viewModel.submit())
        assertNull(viewModel.errorMessage.value)
    }

    @Test
    fun selectReason_clearsPreviousError() {
        val viewModel = ReportPostViewModel()
        viewModel.submit()
        viewModel.selectReason(ReportReason.HARASSMENT)
        assertNull(viewModel.errorMessage.value)
        assertEquals(ReportReason.HARASSMENT, viewModel.selectedReason.value)
    }
}
