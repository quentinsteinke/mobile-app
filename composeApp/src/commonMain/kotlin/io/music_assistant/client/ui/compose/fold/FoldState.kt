package io.music_assistant.client.ui.compose.fold

import androidx.compose.runtime.Immutable
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.DpRect
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width

/**
 * How a folding display is held, from its active division: the part of the window that the fold
 * covers. A division is active only while the device is partially folded, so a fully open or a
 * non-folding device is [Flat]. The division is in window coordinates, in dp.
 */
@Immutable
sealed interface FoldPosture {
    data object Flat : FoldPosture

    /** The fold runs from top to bottom, so content sits side by side. */
    data class Book(val division: DpRect) : FoldPosture

    /** The fold runs from side to side, so content sits above and below it. */
    data class Tabletop(val division: DpRect) : FoldPosture
}

/** The hinge as the platform reports it. Apple says to use it for effects, not for layout. */
enum class HingeStatus { UNKNOWN, CLOSED, PARTIALLY_OPEN, FULLY_OPEN }

/**
 * The fold of the window. Layout follows [posture]. [hinge] is null on a device without a hinge,
 * or while the platform reports none.
 */
@Immutable
data class FoldState(
    val posture: FoldPosture = FoldPosture.Flat,
    val hinge: HingeStatus? = null,
) {
    companion object {
        val Flat = FoldState()

        /**
         * The posture for an active [division], or [FoldPosture.Flat] for none. The direction of
         * the fold comes from the shape of the division: a fold that runs from top to bottom is
         * taller than it is wide. A fold line without width (Android reports one) still counts.
         */
        fun postureOf(division: DpRect?): FoldPosture = when {
            division == null -> FoldPosture.Flat
            division.width <= 0.dp && division.height <= 0.dp -> FoldPosture.Flat
            division.height >= division.width -> FoldPosture.Book(division)
            else -> FoldPosture.Tabletop(division)
        }
    }
}

/** Extra space on each side of the division, so no content sits right at the fold. */
val FoldGutter: Dp = 8.dp

/**
 * Where a division crosses one layout along one axis, in that layout's own coordinates, with
 * [FoldGutter] already added on both sides. [start] is where the content before the fold must
 * end, and [end] is where the content after it may begin.
 */
data class FoldSpan(val start: Dp, val end: Dp)

/**
 * The span of a division from [divisionStart] to [divisionEnd] inside a layout that starts at
 * [layoutStart] and is [layoutSize] long, all in window coordinates along the same axis. Null when
 * the division does not cross the layout, or when either side would be shorter than [minSide].
 */
fun foldSpanWithin(
    divisionStart: Dp,
    divisionEnd: Dp,
    layoutStart: Dp,
    layoutSize: Dp,
    minSide: Dp,
): FoldSpan? {
    val start = divisionStart - layoutStart - FoldGutter
    val end = divisionEnd - layoutStart + FoldGutter
    return FoldSpan(start, end).takeIf { start >= minSide && layoutSize - end >= minSide }
}
