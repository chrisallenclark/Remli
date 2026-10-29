package com.chrisallenclark.remli.capabilities

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DeviceCapabilitiesTest {

    private val gb = 1024L * 1024 * 1024

    private fun facts(
        sdk: Int,
        lowRam: Boolean = false,
        memory: Long = 8 * gb,
        onDeviceSpeech: Boolean = true,
    ) = DeviceFacts(sdk, lowRam, memory, onDeviceSpeech)

    @Test
    fun `Android 8 and 9 are supported but not the polished tier`() {
        for (sdk in 26..28) {
            val c = DeviceCapabilities.from(facts(sdk))
            assertEquals(SupportTier.Supported, c.tier)
            assertFalse("no system dark mode before Android 10", c.followsSystemAppearance)
            assertFalse("no RenderEffect before Android 12", c.backdropBlur)
        }
    }

    @Test
    fun `Android 10 through 16 are the polished tier`() {
        for (sdk in 29..36) {
            val c = DeviceCapabilities.from(facts(sdk))
            assertEquals(SupportTier.Polished, c.tier)
            assertTrue(c.followsSystemAppearance)
        }
    }

    @Test
    fun `blur needs Android 12 and enough memory`() {
        assertFalse(DeviceCapabilities.from(facts(30)).backdropBlur)
        assertTrue(DeviceCapabilities.from(facts(31)).backdropBlur)
        assertFalse(DeviceCapabilities.from(facts(36, lowRam = true)).backdropBlur)
        assertFalse(DeviceCapabilities.from(facts(36, memory = 2 * gb)).backdropBlur)
    }

    @Test
    fun `low memory turns on reduced effects, unknown memory does not`() {
        assertTrue(DeviceCapabilities.from(facts(33, lowRam = true)).reducedEffects)
        assertTrue(DeviceCapabilities.from(facts(33, memory = 2 * gb)).reducedEffects)
        assertFalse(DeviceCapabilities.from(facts(33, memory = 4 * gb)).reducedEffects)
        assertFalse(DeviceCapabilities.from(facts(33, memory = 0)).reducedEffects)
    }

    @Test
    fun `voice is private on Android 12+ with an on-device recogniser`() {
        assertEquals(VoiceCapture.PrivateOnDevice, VoiceCapture.decide(facts(31)))
        assertEquals(VoiceCapture.PrivateOnDevice, VoiceCapture.decide(facts(36)))
    }

    @Test
    fun `voice falls back to typing, never to a cloud recogniser`() {
        // Even if an older phone reports a recogniser, nothing before Android 12 can promise
        // it stays on the device.
        assertEquals(
            VoiceCapture.TypingOnly(VoiceCapture.Reason.OsTooOld),
            VoiceCapture.decide(facts(30, onDeviceSpeech = true)),
        )
        assertEquals(
            VoiceCapture.TypingOnly(VoiceCapture.Reason.NoOnDeviceRecognizer),
            VoiceCapture.decide(facts(34, onDeviceSpeech = false)),
        )
    }

    @Test
    fun `notification permission is asked for from Android 13`() {
        assertFalse(DeviceCapabilities.from(facts(32)).notificationPermissionRequired)
        assertTrue(DeviceCapabilities.from(facts(33)).notificationPermissionRequired)
    }
}
