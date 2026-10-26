package io.music_assistant.client.ui.compose.fold

import androidx.compose.ui.unit.DpRect
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * The fold that the platform host reports, for a platform where Compose cannot read it. iOS
 * reports it from Swift (`iosApp/ContentView.swift`), because the iPhone Duo APIs are UIKit only.
 * Android reports nothing here: Compose already reads its fold (see [ProvideFoldState]).
 */
class FoldStateSource {
    private val _state = MutableStateFlow(FoldState.Flat)
    val state: StateFlow<FoldState> = _state.asStateFlow()

    /** The active division in window coordinates, in dp, or null when no division is active. */
    fun reportDivision(division: DpRect?) {
        _state.update { it.copy(posture = FoldState.postureOf(division)) }
    }

    fun reportHinge(status: HingeStatus?) {
        _state.update { it.copy(hinge = status) }
    }
}
