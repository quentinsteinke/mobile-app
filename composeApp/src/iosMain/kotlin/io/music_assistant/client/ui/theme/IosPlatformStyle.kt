package io.music_assistant.client.ui.theme

import androidx.compose.foundation.LocalIndication
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LocalRippleConfiguration
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.TextFieldColors
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp

/**
 * The iOS look of the shared screens: system colors in light and dark, SF Pro in the HIG type
 * scale, a highlight instead of the Material ripple, rounded filled text fields without an
 * indicator line, and SF Symbols for the icons that have one.
 */
object IosPlatformStyle : PlatformStyle {
    @Composable
    override fun Theme(darkTheme: Boolean, content: @Composable () -> Unit) {
        val colorScheme = remember(darkTheme) { iosColorScheme(darkTheme) }
        MaterialTheme(
            colorScheme = colorScheme,
            typography = iosTypography,
            shapes = iosShapes,
        ) {
            // MaterialTheme provides the ripple, so the iOS feedback goes inside it.
            val highlight = remember(colorScheme) {
                IosHighlightIndication(colorScheme.onSurface.copy(alpha = HIGHLIGHT_ALPHA))
            }
            CompositionLocalProvider(
                LocalRippleConfiguration provides null,
                LocalIndication provides highlight,
                content = content,
            )
        }
    }

    @Composable
    override fun iconPainter(imageVector: ImageVector): Painter? =
        remember(imageVector) { sfSymbolPainter(imageVector) }

    @Composable
    override fun textFieldColors(base: TextFieldColors): TextFieldColors {
        val fill = MaterialTheme.colorScheme.secondaryContainer
        return base.copy(
            focusedContainerColor = fill,
            unfocusedContainerColor = fill,
            disabledContainerColor = fill.copy(alpha = DISABLED_ALPHA),
            errorContainerColor = fill,
            focusedIndicatorColor = Color.Transparent,
            unfocusedIndicatorColor = Color.Transparent,
            disabledIndicatorColor = Color.Transparent,
            errorIndicatorColor = Color.Transparent,
        )
    }

    override val textFieldShape: Shape = RoundedCornerShape(10.dp)

    override val showsExitButton: Boolean = false
}

/** iOS corner radii: menus and small controls, cells and cards, then sheets and large cards. */
private val iosShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),
    small = RoundedCornerShape(10.dp),
    medium = RoundedCornerShape(12.dp),
    large = RoundedCornerShape(16.dp),
    extraLarge = RoundedCornerShape(26.dp),
)

/** The dimming of a pressed element, close to a highlighted table cell. */
private const val HIGHLIGHT_ALPHA = 0.12f

private const val DISABLED_ALPHA = 0.38f
