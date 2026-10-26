package io.music_assistant.client.ui.theme

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.IndicationNodeFactory
import androidx.compose.foundation.interaction.InteractionSource
import androidx.compose.foundation.interaction.PressInteraction
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.ContentDrawScope
import androidx.compose.ui.node.DelegatableNode
import androidx.compose.ui.node.DrawModifierNode
import kotlinx.coroutines.launch

/**
 * The iOS press feedback in place of the Material ripple: the pressed element dims at once and
 * fades back when the finger lifts, as a table cell or a plain button does.
 */
internal data class IosHighlightIndication(private val color: Color) : IndicationNodeFactory {
    override fun create(interactionSource: InteractionSource): DelegatableNode =
        HighlightNode(interactionSource, color)
}

private class HighlightNode(
    private val interactionSource: InteractionSource,
    private val color: Color,
) : Modifier.Node(), DrawModifierNode {
    private val alpha = Animatable(0f)

    override fun onAttach() {
        coroutineScope.launch {
            val presses = mutableSetOf<PressInteraction.Press>()
            interactionSource.interactions.collect { interaction ->
                when (interaction) {
                    is PressInteraction.Press -> presses += interaction
                    is PressInteraction.Release -> presses -= interaction.press
                    is PressInteraction.Cancel -> presses -= interaction.press
                }
                launch {
                    when {
                        presses.isEmpty() -> alpha.animateTo(0f, tween(FADE_OUT_MS))
                        else -> alpha.snapTo(1f)
                    }
                }
            }
        }
    }

    override fun ContentDrawScope.draw() {
        drawContent()
        alpha.value.takeIf { it > 0f }?.let { drawRect(color, alpha = it) }
    }
}

private const val FADE_OUT_MS = 250
