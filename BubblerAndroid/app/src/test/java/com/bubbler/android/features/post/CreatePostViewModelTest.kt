package com.bubbler.android.features.post

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CreatePostViewModelTest {
    @Test
    fun topicNeedsSync_whenOriginalNull_isTrue() {
        assertTrue(CreatePostViewModel.topicNeedsSync(originalTopic = null, selectedTopic = "science"))
    }

    @Test
    fun topicNeedsSync_whenUnchanged_isFalse() {
        assertFalse(
            CreatePostViewModel.topicNeedsSync(
                originalTopic = "Technology",
                selectedTopic = "technology",
            ),
        )
    }

    @Test
    fun topicNeedsSync_whenChanged_isTrue() {
        assertTrue(
            CreatePostViewModel.topicNeedsSync(
                originalTopic = "sports",
                selectedTopic = "science",
            ),
        )
    }
}
