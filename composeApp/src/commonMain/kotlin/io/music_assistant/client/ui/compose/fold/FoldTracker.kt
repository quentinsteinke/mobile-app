package io.music_assistant.client.ui.compose.fold

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Stable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.layout.onPlaced
import androidx.compose.ui.layout.positionInWindow
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.toSize

/**
 * Finds where the fold crosses one layout. Put [modifier] on the layout, then read [bookSpan] or
 * [tabletopSpan]. The first frame after the layout moves still uses its old place.
 */
@Stable
class FoldTracker internal constructor() {
    private var windowBounds by mutableStateOf<Rect?>(null)

    val modifier: Modifier = Modifier.onPlaced {
        windowBounds = Rect(it.positionInWindow(), it.size.toSize())
    }

    /** Where a book fold crosses the layout from start to end, in its own left-to-right coordinates. */
    @Composable
    fun bookSpan(minSide: Dp = 0.dp): FoldSpan? {
        val division = (LocalFoldState.current.posture as? FoldPosture.Book)?.division ?: return null
        val bounds = windowBounds ?: return null
        return with(LocalDensity.current) {
            foldSpanWithin(division.left, division.right, bounds.left.toDp(), bounds.width.toDp(), minSide)
        }
    }

    /** Where a tabletop fold crosses the layout from top to bottom, in its own coordinates. */
    @Composable
    fun tabletopSpan(minSide: Dp = 0.dp): FoldSpan? {
        val division = (LocalFoldState.current.posture as? FoldPosture.Tabletop)?.division ?: return null
        val bounds = windowBounds ?: return null
        return with(LocalDensity.current) {
            foldSpanWithin(division.top, division.bottom, bounds.top.toDp(), bounds.height.toDp(), minSide)
        }
    }
}

@Composable
fun rememberFoldTracker(): FoldTracker = remember { FoldTracker() }
