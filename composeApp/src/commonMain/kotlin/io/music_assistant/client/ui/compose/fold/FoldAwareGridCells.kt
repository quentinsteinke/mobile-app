package io.music_assistant.client.ui.compose.fold

import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp

/**
 * As many columns of at least [minSize] as the width holds, like [GridCells.Adaptive]. With
 * [evenColumns], an odd count above one drops a column, so a grid that a fold crosses divides
 * cleanly at the fold. The cells share the width that the spacing leaves.
 */
class FoldAwareGridCells(private val minSize: Dp, private val evenColumns: Boolean) : GridCells {
    override fun Density.calculateCrossAxisCellSizes(availableSize: Int, spacing: Int): List<Int> {
        val fits = ((availableSize + spacing) / (minSize.roundToPx() + spacing)).coerceAtLeast(1)
        val count = if (evenColumns && fits > 1 && fits % 2 == 1) fits - 1 else fits
        val cellsWidth = availableSize - spacing * (count - 1)
        val cellWidth = cellsWidth / count
        val remainder = cellsWidth % count
        return List(count) { cellWidth + if (it < remainder) 1 else 0 }
    }

    override fun equals(other: Any?): Boolean =
        other is FoldAwareGridCells && minSize == other.minSize && evenColumns == other.evenColumns

    override fun hashCode(): Int = 31 * minSize.hashCode() + evenColumns.hashCode()
}
