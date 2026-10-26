@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

package io.music_assistant.client.ui.theme

import androidx.compose.material3.ColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import kotlinx.cinterop.alloc
import kotlinx.cinterop.memScoped
import kotlinx.cinterop.ptr
import kotlinx.cinterop.value
import platform.CoreGraphics.CGFloatVar
import platform.UIKit.UIColor
import platform.UIKit.UIScreen
import platform.UIKit.UITraitCollection
import platform.UIKit.UIUserInterfaceStyle
import platform.UIKit.labelColor
import platform.UIKit.opaqueSeparatorColor
import platform.UIKit.resolvedColorWithTraitCollection
import platform.UIKit.secondaryLabelColor
import platform.UIKit.secondarySystemBackgroundColor
import platform.UIKit.separatorColor
import platform.UIKit.systemBackgroundColor
import platform.UIKit.systemBlueColor
import platform.UIKit.systemGray5Color
import platform.UIKit.systemGray6Color
import platform.UIKit.systemGrayColor
import platform.UIKit.systemIndigoColor
import platform.UIKit.systemRedColor
import platform.UIKit.tertiarySystemFillColor

/**
 * A Material color scheme made of the iOS system colors, so the shared screens use the same
 * backgrounds, labels, separators and accent as the native parts of the app. The dynamic colors
 * are resolved for the given appearance and for the current contrast setting.
 */
internal fun iosColorScheme(darkTheme: Boolean): ColorScheme {
    val traits = UITraitCollection.traitCollectionWithTraitsFromCollections(
        listOf(
            UIScreen.mainScreen.traitCollection,
            UITraitCollection.traitCollectionWithUserInterfaceStyle(
                if (darkTheme) {
                    UIUserInterfaceStyle.UIUserInterfaceStyleDark
                } else {
                    UIUserInterfaceStyle.UIUserInterfaceStyleLight
                },
            ),
        ),
    )
    fun UIColor.resolved(): Color = resolvedColorWithTraitCollection(traits).toComposeColor()

    val background = UIColor.systemBackgroundColor.resolved()
    val label = UIColor.labelColor.resolved()
    val accent = UIColor.systemBlueColor.resolved()
    val red = UIColor.systemRedColor.resolved()
    val indigo = UIColor.systemIndigoColor.resolved()
    val gray6 = UIColor.systemGray6Color.resolved()
    val gray5 = UIColor.systemGray5Color.resolved()
    val fill = UIColor.tertiarySystemFillColor.resolved().compositeOver(background)
    val separator = UIColor.separatorColor.resolved().compositeOver(background)
    fun Color.tinted(): Color = copy(alpha = TINT_ALPHA).compositeOver(background)

    val base = if (darkTheme) darkColorScheme() else lightColorScheme()
    return base.copy(
        primary = accent,
        onPrimary = Color.White,
        primaryContainer = accent.tinted(),
        onPrimaryContainer = accent,
        inversePrimary = accent,
        secondary = UIColor.systemGrayColor.resolved(),
        onSecondary = Color.White,
        secondaryContainer = fill,
        onSecondaryContainer = label,
        tertiary = indigo,
        onTertiary = Color.White,
        tertiaryContainer = indigo.tinted(),
        onTertiaryContainer = indigo,
        background = background,
        onBackground = label,
        surface = background,
        onSurface = label,
        surfaceVariant = UIColor.secondarySystemBackgroundColor.resolved(),
        onSurfaceVariant = UIColor.secondaryLabelColor.resolved().compositeOver(background),
        // No tonal elevation tint: iOS separates layers by background color, not by tint.
        surfaceTint = Color.Transparent,
        inverseSurface = label,
        inverseOnSurface = background,
        error = red,
        onError = Color.White,
        errorContainer = red.tinted(),
        onErrorContainer = red,
        outline = UIColor.opaqueSeparatorColor.resolved(),
        outlineVariant = separator,
        scrim = Color.Black,
        surfaceBright = background,
        surfaceDim = gray6,
        surfaceContainerLowest = background,
        surfaceContainerLow = gray6,
        surfaceContainer = gray6,
        surfaceContainerHigh = gray6,
        surfaceContainerHighest = gray5,
    )
}

private fun UIColor.toComposeColor(): Color = memScoped {
    val red = alloc<CGFloatVar>()
    val green = alloc<CGFloatVar>()
    val blue = alloc<CGFloatVar>()
    val alpha = alloc<CGFloatVar>()
    getRed(red.ptr, green.ptr, blue.ptr, alpha.ptr)
    // Extended sRGB components can fall outside 0..1 for wide-gamut colors.
    Color(
        red = red.value.toFloat().coerceIn(0f, 1f),
        green = green.value.toFloat().coerceIn(0f, 1f),
        blue = blue.value.toFloat().coerceIn(0f, 1f),
        alpha = alpha.value.toFloat().coerceIn(0f, 1f),
    )
}

/** The strength of a tinted container, as in the iOS tinted button and badge backgrounds. */
private const val TINT_ALPHA = 0.15f
