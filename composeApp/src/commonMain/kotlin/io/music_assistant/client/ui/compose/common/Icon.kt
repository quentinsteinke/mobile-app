package io.music_assistant.client.ui.compose.common

import androidx.compose.material3.LocalContentColor
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.vector.ImageVector
import io.music_assistant.client.ui.theme.LocalPlatformStyle
import androidx.compose.material3.Icon as MaterialIcon

/**
 * The Material [androidx.compose.material3.Icon], except that a platform style can draw a native
 * glyph for the vector (SF Symbols on iOS). Use this one in the shared screens.
 */
@Composable
fun Icon(
    imageVector: ImageVector,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    tint: Color = LocalContentColor.current,
) {
    when (val painter = LocalPlatformStyle.current?.iconPainter(imageVector)) {
        null -> MaterialIcon(imageVector, contentDescription, modifier, tint)
        else -> MaterialIcon(painter, contentDescription, modifier, tint)
    }
}

@Composable
fun Icon(
    painter: Painter,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    tint: Color = LocalContentColor.current,
) = MaterialIcon(painter, contentDescription, modifier, tint)

@Composable
fun Icon(
    bitmap: ImageBitmap,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    tint: Color = LocalContentColor.current,
) = MaterialIcon(bitmap, contentDescription, modifier, tint)
