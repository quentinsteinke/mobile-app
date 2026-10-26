package io.music_assistant.client.feature

import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.test.click
import androidx.compose.ui.test.getUnclippedBoundsInRoot
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performTouchInput
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.height
import androidx.compose.ui.unit.width
import androidx.test.ext.junit.runners.AndroidJUnit4
import io.music_assistant.client.api.ServiceClient
import io.music_assistant.client.support.FakeServiceClient
import io.music_assistant.client.support.Qualifiers
import io.music_assistant.client.support.ServerMediaItemFixtures
import io.music_assistant.client.support.ServerPlayerFixtures
import io.music_assistant.client.support.get
import io.music_assistant.client.support.isTab
import io.music_assistant.client.support.launchLoggedInApp
import io.music_assistant.client.support.pages.ExpandedPlayerPage
import io.music_assistant.client.support.pages.HomePage
import io.music_assistant.client.support.pages.assertOnPage
import io.music_assistant.client.support.pages.assertPlayer
import io.music_assistant.client.support.pages.playMedia
import io.music_assistant.client.support.rules.createTestRuleChain
import io.music_assistant.client.ui.compose.home.CollapsibleQueueSemantics
import io.music_assistant.client.ui.compose.home.FloatingBarSemantics
import musicassistantclient.composeapp.generated.resources.Res
import musicassistantclient.composeapp.generated.resources.nav_library
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.koin.java.KoinJavaComponent.inject
import org.robolectric.annotation.Config
import kotlin.test.assertTrue

@RunWith(AndroidJUnit4::class)
class AdaptiveLayoutTest {
    @get:Rule
    val testRuleChain = createTestRuleChain()

    @get:Rule
    val composeTestRule = createComposeRule()

    private val serviceClient: FakeServiceClient by inject(ServiceClient::class.java)

    @Test
    @Config(qualifiers = Qualifiers.MEDIUM_PHONE)
    fun `a phone shows the bottom bar and the queue under the player`() {
        val home = launchWithTrack()
        assertTrue(libraryTab().top > root().height / 2, "navigation is at the bottom")

        home.expandPlaying()
        composeTestRule.onNodeWithTag(CollapsibleQueueSemantics.QUEUE_TAG).assertDoesNotExist()
    }

    @Test
    @Config(qualifiers = Qualifiers.FOLDABLE_INNER_PORTRAIT)
    fun `a medium-width portrait window shows the rail and the queue beside the player`() {
        val home = launchWithTrack()
        val tab = libraryTab()
        assertTrue(tab.right <= 80.dp && tab.bottom < root().height / 2, "navigation is a rail at the start edge")

        home.expandPlaying()
        val queue = composeTestRule.onNodeWithTag(CollapsibleQueueSemantics.QUEUE_TAG).getUnclippedBoundsInRoot()
        assertTrue(queue.left >= root().width / 2, "queue is in the end pane")
    }

    private val track = ServerMediaItemFixtures.track()
    private val player = ServerPlayerFixtures.player()

    private fun launchWithTrack(): HomePage {
        serviceClient.addItems(track)
        serviceClient.addPlayers(player)
        return launchLoggedInApp(composeTestRule, serviceClient)
    }

    // A wide bar holds inline controls at its center, so tap its start edge to expand it.
    private fun HomePage.expandPlaying() {
        playMedia(track).assertPlayer(player.displayName, playing = true, item = track.name)
        composeTestRule.onNodeWithTag(FloatingBarSemantics.TAG)
            .performTouchInput { click(centerLeft + Offset(24f, 0f)) }
        ExpandedPlayerPage(player.displayName, true, track.name, composeTestRule).assertOnPage()
    }

    private fun root() = composeTestRule.onRoot().getUnclippedBoundsInRoot()

    private fun libraryTab() =
        composeTestRule.onNode(isTab(Res.string.nav_library.get())).getUnclippedBoundsInRoot()
}
