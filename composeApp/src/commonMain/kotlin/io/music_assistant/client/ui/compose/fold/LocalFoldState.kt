package io.music_assistant.client.ui.compose.fold

import androidx.compose.material3.adaptive.HingeInfo
import androidx.compose.material3.adaptive.currentWindowAdaptiveInfoV2
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.DpRect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import org.koin.compose.koinInject

/** The fold of the window. [FoldState.Flat] when nothing provides it. */
val LocalFoldState = staticCompositionLocalOf { FoldState.Flat }

/**
 * Provides [LocalFoldState]. On Android, material3-adaptive reads the Jetpack WindowManager
 * `FoldingFeature` into the window posture. On iOS the posture has no hinges, and Swift reports
 * the iPhone Duo division through [FoldStateSource]. A reported division wins over the posture.
 */
@Composable
fun ProvideFoldState(content: @Composable () -> Unit) {
    val reported by koinInject<FoldStateSource>().state.collectAsStateWithLifecycle()
    val hinges = currentWindowAdaptiveInfoV2().windowPosture.hingeList
    val density = LocalDensity.current
    val state = remember(reported, hinges, density) {
        val fromHinges = foldStateOf(hinges, density)
        FoldState(
            posture = reported.posture.takeUnless { it == FoldPosture.Flat } ?: fromHinges.posture,
            hinge = reported.hinge ?: fromHinges.hinge,
        )
    }
    CompositionLocalProvider(LocalFoldState provides state, content)
}

/**
 * The fold from the window posture. A separating hinge is a fold that is partially open (or the
 * gap between two screens), so it divides the window. Its bounds are in window pixels.
 */
private fun foldStateOf(hinges: List<HingeInfo>, density: Density): FoldState {
    val division = hinges.firstOrNull { it.isSeparating }?.bounds?.let { bounds ->
        with(density) { DpRect(bounds.left.toDp(), bounds.top.toDp(), bounds.right.toDp(), bounds.bottom.toDp()) }
    }
    val hinge = when {
        hinges.isEmpty() -> null
        hinges.all { it.isFlat } -> HingeStatus.FULLY_OPEN
        else -> HingeStatus.PARTIALLY_OPEN
    }
    return FoldState(FoldState.postureOf(division), hinge)
}
