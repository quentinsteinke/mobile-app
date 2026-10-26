package io.music_assistant.client.ui.compose.fold

import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class FoldStateTest {
    // The iPhone Duo inner display in portrait, with the fold across the middle.
    private val bookDivision = DpRect(left = 322.dp, top = 0.dp, right = 347.dp, bottom = 951.dp)
    private val tabletopDivision = DpRect(left = 0.dp, top = 322.dp, right = 951.dp, bottom = 347.dp)

    @Test
    fun `no division is flat`() {
        assertEquals(FoldPosture.Flat, FoldState.postureOf(null))
        assertEquals(FoldPosture.Flat, FoldState.postureOf(DpRect(10.dp, 10.dp, 10.dp, 10.dp)))
    }

    @Test
    fun `a fold from top to bottom is book posture`() {
        assertEquals(FoldPosture.Book(bookDivision), FoldState.postureOf(bookDivision))
    }

    @Test
    fun `a fold line without width is book posture`() {
        val line = DpRect(left = 334.dp, top = 0.dp, right = 334.dp, bottom = 951.dp)
        assertEquals(FoldPosture.Book(line), FoldState.postureOf(line))
    }

    @Test
    fun `a fold from side to side is tabletop posture`() {
        assertEquals(FoldPosture.Tabletop(tabletopDivision), FoldState.postureOf(tabletopDivision))
    }

    @Test
    fun `the source keeps the division and the hinge apart`() {
        val source = FoldStateSource()

        source.reportHinge(HingeStatus.PARTIALLY_OPEN)
        source.reportDivision(bookDivision)
        assertEquals(FoldState(FoldPosture.Book(bookDivision), HingeStatus.PARTIALLY_OPEN), source.state.value)

        source.reportDivision(null)
        assertEquals(FoldState(FoldPosture.Flat, HingeStatus.PARTIALLY_OPEN), source.state.value)
    }

    @Test
    fun `a span is in the layout's own coordinates with a gutter on each side`() {
        // A layout that starts after an 80 dp navigation rail.
        val span = foldSpanWithin(322.dp, 347.dp, layoutStart = 80.dp, layoutSize = 589.dp, minSide = 160.dp)

        assertEquals(FoldSpan(start = 322.dp - 80.dp - FoldGutter, end = 347.dp - 80.dp + FoldGutter), span)
    }

    @Test
    fun `a fold outside the layout or too near its edge gives no span`() {
        assertNull(foldSpanWithin(322.dp, 347.dp, layoutStart = 400.dp, layoutSize = 269.dp, minSide = 0.dp))
        assertNull(foldSpanWithin(322.dp, 347.dp, layoutStart = 0.dp, layoutSize = 400.dp, minSide = 160.dp))
    }

    @Test
    fun `grid columns fill the width and drop to an even count at a fold`() {
        val density = Density(1f)
        fun columns(evenColumns: Boolean) = with(FoldAwareGridCells(140.dp, evenColumns)) {
            density.calculateCrossAxisCellSizes(availableSize = 589, spacing = 4)
        }

        // 589 dp holds 4 columns of 140 dp, already an even count.
        assertEquals(listOf(144, 144, 144, 145).sorted(), columns(evenColumns = true).sorted())
        assertEquals(589, columns(evenColumns = false).sum() + 3 * 4)

        val threeColumns = with(FoldAwareGridCells(180.dp, evenColumns = false)) {
            density.calculateCrossAxisCellSizes(availableSize = 589, spacing = 4)
        }
        val evenColumns = with(FoldAwareGridCells(180.dp, evenColumns = true)) {
            density.calculateCrossAxisCellSizes(availableSize = 589, spacing = 4)
        }
        assertEquals(3, threeColumns.size)
        assertEquals(2, evenColumns.size)
        assertEquals(589, evenColumns.sum() + 4)
    }
}
