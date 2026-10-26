package io.music_assistant.client.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * The iOS text styles of the Human Interface Guidelines (default Dynamic Type size) in the
 * system font, SF Pro. The tracking is Apple's tracking for each size. [ProvideDynamicTypeFontScale]
 * scales these sizes with the Dynamic Type setting.
 */
private fun hig(size: Int, lineHeight: Int, tracking: Double, weight: FontWeight) = TextStyle(
    fontFamily = FontFamily.Default,
    fontWeight = weight,
    fontSize = size.sp,
    lineHeight = lineHeight.sp,
    letterSpacing = tracking.sp,
)

private val largeTitle = hig(34, 41, 0.40, FontWeight.Bold)
private val title1 = hig(28, 34, 0.38, FontWeight.Bold)
private val title2 = hig(22, 28, -0.26, FontWeight.Bold)
private val title3 = hig(20, 25, -0.45, FontWeight.SemiBold)
private val headline = hig(17, 22, -0.43, FontWeight.SemiBold)
private val body = hig(17, 22, -0.43, FontWeight.Normal)
private val callout = hig(16, 21, -0.31, FontWeight.Medium)
private val subheadline = hig(15, 20, -0.23, FontWeight.Normal)
private val footnote = hig(13, 18, -0.08, FontWeight.Normal)
private val caption1 = hig(12, 16, 0.0, FontWeight.Medium)

private fun TextStyle.emphasized() = copy(fontWeight = FontWeight.Bold)

/**
 * The Material roles mapped to the iOS styles. The top app bar title (`titleLarge`) gets Title 3,
 * between the inline navigation title and the large title. Buttons and chips (`labelLarge`) get
 * Callout.
 */
internal val iosTypography: Typography = Typography(
    displayLarge = largeTitle,
    displayMedium = title1,
    displaySmall = title2,
    headlineLarge = largeTitle,
    headlineMedium = title1,
    headlineSmall = title2,
    titleLarge = title3,
    titleMedium = headline,
    titleSmall = subheadline.copy(fontWeight = FontWeight.SemiBold),
    bodyLarge = body,
    bodyMedium = subheadline,
    bodySmall = footnote,
    labelLarge = callout,
    labelMedium = footnote.copy(fontWeight = FontWeight.Medium),
    labelSmall = caption1,
    displayLargeEmphasized = largeTitle.emphasized(),
    displayMediumEmphasized = title1.emphasized(),
    displaySmallEmphasized = title2.emphasized(),
    headlineLargeEmphasized = largeTitle.emphasized(),
    headlineMediumEmphasized = title1.emphasized(),
    headlineSmallEmphasized = title2.emphasized(),
    titleLargeEmphasized = title3.emphasized(),
    titleMediumEmphasized = headline.emphasized(),
    titleSmallEmphasized = subheadline.emphasized(),
    bodyLargeEmphasized = headline,
    bodyMediumEmphasized = subheadline.copy(fontWeight = FontWeight.SemiBold),
    bodySmallEmphasized = footnote.copy(fontWeight = FontWeight.SemiBold),
    labelLargeEmphasized = callout.emphasized(),
    labelMediumEmphasized = footnote.emphasized(),
    labelSmallEmphasized = caption1.emphasized(),
)
