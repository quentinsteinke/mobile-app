@file:OptIn(kotlinx.cinterop.ExperimentalForeignApi::class)

package io.music_assistant.client.ui.theme

import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.graphics.FilterQuality
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.painter.Painter
import androidx.compose.ui.graphics.toComposeImageBitmap
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import kotlinx.cinterop.addressOf
import kotlinx.cinterop.useContents
import kotlinx.cinterop.usePinned
import org.jetbrains.skia.Image
import platform.CoreGraphics.CGRectMake
import platform.Foundation.NSData
import platform.UIKit.UIColor
import platform.UIKit.UIGraphicsImageRenderer
import platform.UIKit.UIGraphicsImageRendererFormat
import platform.UIKit.UIImage
import platform.UIKit.UIImagePNGRepresentation
import platform.UIKit.UIImageRenderingMode
import platform.UIKit.UIImageSymbolConfiguration
import platform.UIKit.UIImageSymbolWeightRegular
import platform.posix.memcpy
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * The SF Symbol that replaces a vector icon on iOS, keyed by [ImageVector.name]. Material icons
 * are named "<Theme>.<Icon>"; the custom icons in `ui/compose/common/icons`, Tabler and FontAwesome
 * icons by their own name.
 * An icon that is not in the table, or a symbol that this iOS version lacks, keeps its vector.
 */
private val symbolNames = mapOf(
    // Navigation and generic actions
    "AutoMirrored.Filled.ArrowBack" to "chevron.backward",
    "AutoMirrored.Filled.KeyboardArrowRight" to "chevron.forward",
    "Filled.ExpandMore" to "chevron.down",
    "Filled.ExpandLess" to "chevron.up",
    "Filled.ArrowUpward" to "arrow.up",
    "Filled.ArrowDownward" to "arrow.down",
    "Filled.SwapHoriz" to "arrow.left.arrow.right",
    "Filled.Check" to "checkmark",
    "Filled.Done" to "checkmark",
    "Filled.Close" to "xmark",
    "Filled.Clear" to "xmark.circle.fill",
    "Filled.Add" to "plus",
    "Filled.Remove" to "minus",
    "Filled.Delete" to "trash",
    "Filled.DeleteSweep" to "trash",
    "Filled.Edit" to "pencil",
    "Filled.MoreVert" to "ellipsis",
    "Filled.Refresh" to "arrow.clockwise",
    "Filled.Replay" to "arrow.counterclockwise",
    "Filled.RestartAlt" to "arrow.counterclockwise",
    "Filled.Search" to "magnifyingglass",
    "Filled.FilterList" to "line.3.horizontal.decrease",
    "Filled.Tune" to "slider.horizontal.3",
    "Filled.Settings" to "gearshape",
    "Filled.Home" to "house.fill",
    "Filled.PowerSettingsNew" to "power",
    "Filled.Link" to "link",
    "Filled.Visibility" to "eye",
    "Filled.VisibilityOff" to "eye.slash",
    "Filled.QrCodeScanner" to "qrcode.viewfinder",
    "Filled.Person" to "person.fill",
    "Filled.Groups" to "person.3.fill",
    "Filled.Schedule" to "clock",
    "Filled.Bedtime" to "moon.zzz",
    "Filled.Palette" to "paintpalette",
    "Filled.Folder" to "folder.fill",
    "Outlined.Folder" to "folder",
    "Filled.GridView" to "square.grid.2x2",
    "AutoMirrored.Filled.List" to "list.bullet",
    "AutoMirrored.Filled.ViewList" to "list.bullet",
    "AutoMirrored.Filled.Input" to "arrow.right.square",
    "Filled.Downloading" to "arrow.down.circle",
    "Filled.AutoAwesome" to "sparkles",
    "Filled.SmartToy" to "sparkles",
    "Filled.AllInclusive" to "infinity",
    // Library and media
    "Filled.LibraryMusic" to "square.stack.fill",
    "Filled.MusicNote" to "music.note",
    "Filled.Album" to "square.stack",
    "Filled.Podcasts" to "antenna.radiowaves.left.and.right",
    "Filled.CellTower" to "antenna.radiowaves.left.and.right",
    "Filled.Waves" to "water.waves",
    "Filled.Explicit" to "e.square.fill",
    "Filled.Mic" to "mic.fill",
    "Filled.RecordVoiceOver" to "person.wave.2",
    "Filled.Campaign" to "megaphone.fill",
    "AutoMirrored.Filled.LibraryBooks" to "books.vertical.fill",
    "Filled.Favorite" to "heart.fill",
    "Outlined.FavoriteBorder" to "heart",
    "Filled.ThumbDown" to "hand.thumbsdown.fill",
    "Outlined.Lyrics" to "quote.bubble",
    // Queue and playlists
    "AutoMirrored.Filled.PlaylistAdd" to "text.badge.plus",
    "Filled.PlaylistAddCircle" to "text.badge.plus",
    "Filled.PlaylistRemove" to "text.badge.minus",
    "AutoMirrored.Filled.PlaylistPlay" to "music.note.list",
    "Filled.QueuePlayNext" to "text.line.first.and.arrowtriangle.forward",
    "Filled.AddToQueue" to "text.append",
    // Transport
    "Filled.PlayArrow" to "play.fill",
    "Filled.Shuffle" to "shuffle",
    "Rounded.Replay10" to "gobackward.10",
    "Rounded.Forward30" to "goforward.30",
    "Play" to "play.fill",
    "Pause" to "pause.fill",
    "Stop" to "stop.fill",
    "SkipForward" to "forward.fill",
    "SkipBack" to "backward.fill",
    // The "on" states are filled circles, so the state stays visible with one tint.
    "ShuffleOff" to "shuffle",
    "ShuffleOn" to "shuffle.circle.fill",
    "RepeatOff" to "repeat",
    "RepeatOn" to "repeat.circle.fill",
    "RepeatOne" to "repeat.1.circle.fill",
    "Volume" to "speaker.wave.2.fill",
    "VolumeMuted" to "speaker.slash.fill",
    "SpeakerMultiple" to "hifispeaker.2.fill",
    // Media types
    "Album" to "square.stack",
    "Artist" to "music.microphone",
    "Track" to "music.note",
    "Playlist" to "music.note.list",
    "Radio" to "dot.radiowaves.left.and.right",
    "Genre" to "guitars",
    "BookAudio" to "headphones",
    "Bookshelf" to "books.vertical",
    // FontAwesome: the appearance choice in Settings
    "Sun" to "sun.max.fill",
    "Adn" to "circle.lefthalf.filled",
    "Moon" to "moon.fill",
    // Tabler
    "GripVertical" to "line.3.horizontal",
    "Plus" to "plus",
    "ThumbDown" to "hand.thumbsdown",
    "Heart" to "heart",
    "HeartBroken" to "heart.slash",
    "FolderPlus" to "folder.badge.plus",
    "FolderMinus" to "folder.badge.minus",
)

/** The SF Symbol name for [imageVector], for native chrome that draws the symbol itself. */
internal fun sfSymbolName(imageVector: ImageVector): String? = symbolNames[imageVector.name]

/** Rendered glyphs by symbol name. Compose draws on the main thread, so a plain map is enough. */
private val glyphCache = mutableMapOf<String, ImageBitmap?>()

/** The SF Symbol painter for [imageVector], or null when the vector has no symbol. */
internal fun sfSymbolPainter(imageVector: ImageVector): Painter? =
    sfSymbolName(imageVector)
        ?.let { name -> glyphCache.getOrPut(name) { renderSymbol(name) } }
        ?.let(::SfSymbolPainter)

/**
 * Draws a pre-rendered symbol glyph fitted into the icon bounds. The intrinsic size is unspecified,
 * so the Material Icon gives it the usual 24 dp, and the glyph fills the same share of the box as
 * a Material glyph fills its 24 dp viewport.
 */
private class SfSymbolPainter(private val glyph: ImageBitmap) : Painter() {
    private var colorFilter: ColorFilter? = null

    override val intrinsicSize: Size = Size.Unspecified

    override fun applyColorFilter(colorFilter: ColorFilter?): Boolean {
        this.colorFilter = colorFilter
        return true
    }

    override fun DrawScope.onDraw() {
        val scale = min(size.width / glyph.width, size.height / glyph.height) * GLYPH_SHARE
        val width = (glyph.width * scale).roundToInt()
        val height = (glyph.height * scale).roundToInt()
        drawImage(
            image = glyph,
            dstOffset = IntOffset(
                ((size.width - width) / 2).roundToInt(),
                ((size.height - height) / 2).roundToInt(),
            ),
            dstSize = IntSize(width, height),
            colorFilter = colorFilter,
            filterQuality = FilterQuality.High,
        )
    }
}

/** Renders the symbol in black on transparent, large enough to scale down sharply. */
private fun renderSymbol(name: String): ImageBitmap? {
    val configuration = UIImageSymbolConfiguration.configurationWithPointSize(
        RENDER_POINT_SIZE,
        UIImageSymbolWeightRegular,
    )
    val symbol = UIImage.systemImageNamed(name, withConfiguration = configuration)
        ?.imageWithTintColor(UIColor.blackColor, UIImageRenderingMode.UIImageRenderingModeAlwaysOriginal)
        ?: return null
    val (width, height) = symbol.size.useContents { width to height }
    val format = UIGraphicsImageRendererFormat.preferredFormat().apply { scale = RENDER_SCALE }
    val rendered = UIGraphicsImageRenderer(size = symbol.size, format = format).imageWithActions { _ ->
        symbol.drawInRect(CGRectMake(0.0, 0.0, width, height))
    }
    return UIImagePNGRepresentation(rendered)
        ?.toByteArray()
        ?.let { Image.makeFromEncoded(it).toComposeImageBitmap() }
}

private fun NSData.toByteArray(): ByteArray = ByteArray(length.toInt()).also { bytes ->
    bytes.usePinned { memcpy(it.addressOf(0), this.bytes, length) }
}

private const val RENDER_POINT_SIZE = 40.0
private const val RENDER_SCALE = 3.0

/** A Material glyph spans about 20 of the 24 dp of its viewport. */
private const val GLYPH_SHARE = 20f / 24f
