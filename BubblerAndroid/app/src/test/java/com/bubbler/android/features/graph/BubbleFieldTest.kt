package com.bubbler.android.features.graph

import com.bubbler.android.features.graph.components.bubbleAngle
import org.junit.Assert.assertEquals
import org.junit.Test
import kotlin.math.PI

class BubbleFieldTest {
    @Test
    fun bubbleAngle_emptyTotal_returnsZero() {
        assertEquals(0.0, bubbleAngle(index = 0, total = 0), 0.0)
    }

    @Test
    fun bubbleAngle_fourChoices_startsAtTopAndSpacesEvenly() {
        assertEquals(-PI / 2.0, bubbleAngle(index = 0, total = 4), 1e-9)
        assertEquals(0.0, bubbleAngle(index = 1, total = 4), 1e-9)
        assertEquals(PI / 2.0, bubbleAngle(index = 2, total = 4), 1e-9)
        assertEquals(PI, bubbleAngle(index = 3, total = 4), 1e-9)
    }

    @Test
    fun bubbleAngle_singleChoice_isAtTop() {
        assertEquals(-PI / 2.0, bubbleAngle(index = 0, total = 1), 1e-9)
    }
}
