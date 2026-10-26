package io.music_assistant.client.ui.theme

import androidx.compose.material3.TextFieldColors
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector

/**
 * The look and conventions of a platform that does not use Material, for the shared screens.
 * Only iOS provides one ([LocalPlatformStyle]). Without it, every hook below keeps the Material
 * behaviour, so Android does not change.
 */
interface PlatformStyle {
    /** Replaces the Material theme of [AppTheme]. */
    @Composable
    fun Theme(darkTheme: Boolean, content: @Composable () -> Unit)

    /** A native glyph for [imageVector], or null to draw the vector. */
    @Composable
    fun iconPainter(imageVector: ImageVector): Painter?

    /** The colors of a filled text field, made from the colors that the field asks for. */
    @Composable
    fun textFieldColors(base: TextFieldColors): TextFieldColors

    val textFieldShape: Shape

    /** False where an app must not quit itself, as on iOS. */
    val showsExitButton: Boolean
}

val LocalPlatformStyle = staticCompositionLocalOf<PlatformStyle?> { null }

/** These colors with the text field style of the platform. */
@Composable
fun TextFieldColors.platformStyled(): TextFieldColors =
    LocalPlatformStyle.current?.textFieldColors(this) ?: this

/** The shape of a filled text field on this platform. */
@Composable
fun platformTextFieldShape(): Shape = LocalPlatformStyle.current?.textFieldShape ?: TextFieldDefaults.shape
