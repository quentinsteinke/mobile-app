package io.music_assistant.client.ui.compose.fold

import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp

/** The narrowest pane that [FoldAwareRow] puts on one side of a fold. */
private val MinPaneWidth = 160.dp

/**
 * Two panes side by side, in a bounded width. When a book fold crosses the row, the panes split
 * at the fold, and the division and a [FoldGutter] on each side of it stay empty. Otherwise
 * [startWidth] sizes the start pane from the width of the row, and [divider] fills the [spacing]
 * between the panes.
 */
@Composable
fun FoldAwareRow(
    startWidth: (maxWidth: Dp) -> Dp,
    modifier: Modifier = Modifier,
    spacing: Dp = 0.dp,
    divider: @Composable () -> Unit = {},
    start: @Composable () -> Unit,
    end: @Composable () -> Unit,
) {
    val tracker = rememberFoldTracker()
    val fold = tracker.bookSpan(minSide = MinPaneWidth)
    Layout(
        contents = listOf(start, divider, end),
        modifier = modifier.then(tracker.modifier),
    ) { (startMeasurables, dividerMeasurables, endMeasurables), constraints ->
        val width = constraints.maxWidth
        // The fold is in left-to-right coordinates, and the panes are placed from the start edge.
        val split = fold?.let {
            val left = it.start.roundToPx()
            val right = it.end.roundToPx()
            when (layoutDirection) {
                LayoutDirection.Ltr -> left to right
                LayoutDirection.Rtl -> width - right to width - left
            }
        }
        val (startEnd, endStart) = split ?: run {
            val spacingPx = spacing.roundToPx()
            val startPx = startWidth(width.toDp()).roundToPx().coerceIn(0, (width - spacingPx).coerceAtLeast(0))
            startPx to startPx + spacingPx
        }
        val startPlaceables = startMeasurables.map {
            it.measure(constraints.copy(minWidth = startEnd, maxWidth = startEnd))
        }
        val endWidth = (width - endStart).coerceAtLeast(0)
        val endPlaceables = endMeasurables.map {
            it.measure(constraints.copy(minWidth = endWidth, maxWidth = endWidth))
        }
        val height = (startPlaceables + endPlaceables).maxOfOrNull { it.height }
            ?.coerceIn(constraints.minHeight, constraints.maxHeight)
            ?: constraints.minHeight
        // The divider marks a flat seam only: at a fold, the empty division is the seam.
        val dividerPlaceables = if (split == null) {
            dividerMeasurables.map { it.measure(Constraints.fixed(endStart - startEnd, height)) }
        } else {
            emptyList()
        }
        layout(width, height) {
            startPlaceables.forEach { it.placeRelative(0, 0) }
            dividerPlaceables.forEach { it.placeRelative(startEnd, 0) }
            endPlaceables.forEach { it.placeRelative(endStart, 0) }
        }
    }
}
