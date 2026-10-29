package com.chrisallenclark.remli.capabilities

/**
 * What this phone can do, decided once and asked everywhere.
 *
 * Remli runs on Android 8 through 16, on flagships and on £150 phones, and a feature that
 * only exists on some of them must degrade to something that still works rather than to an
 * error or a dead button. Every such decision is made here, from plain facts about the
 * device, so it can be tested without a device and so no screen ever grows its own
 * `if (Build.VERSION.SDK_INT ...)` that the others disagree with.
 *
 * The iOS app has no equivalent because it targets one OS version on hardware Apple
 * controls; its nearest relative is the engine status shown in Settings.
 */
data class DeviceCapabilities(
    val tier: SupportTier,

    /**
     * Real frosted-glass blur behind bars and sheets, as iOS draws with materials.
     * Needs Android 12's RenderEffect, and is withheld on low-memory phones where it costs
     * frames. The fallback is a translucent solid surface in the same colour.
     */
    val backdropBlur: Boolean,

    /**
     * Whether "System" can be offered as an appearance. Android 8 and 9 have no system-wide
     * dark mode, so there is nothing to follow; the setting offers Light and Dark only.
     */
    val followsSystemAppearance: Boolean,

    /** Fewer, cheaper effects: no blur, no animated glow on the Map, smaller caches. */
    val reducedEffects: Boolean,

    val voiceCapture: VoiceCapture,

    /** Android 13+ asks before an app may post notifications. Matters from A6. */
    val notificationPermissionRequired: Boolean,
) {
    companion object {
        /** Below this much RAM a phone is treated as low-memory even if it does not say so. */
        const val LOW_MEMORY_BYTES: Long = 3L * 1024 * 1024 * 1024

        fun from(facts: DeviceFacts): DeviceCapabilities {
            val reducedEffects = facts.isLowRamDevice || facts.totalMemoryBytes in 1 until LOW_MEMORY_BYTES
            return DeviceCapabilities(
                tier = if (facts.sdkInt >= SDK_ANDROID_10) SupportTier.Polished else SupportTier.Supported,
                backdropBlur = facts.sdkInt >= SDK_ANDROID_12 && !reducedEffects,
                followsSystemAppearance = facts.sdkInt >= SDK_ANDROID_10,
                reducedEffects = reducedEffects,
                voiceCapture = VoiceCapture.decide(facts),
                notificationPermissionRequired = facts.sdkInt >= SDK_ANDROID_13,
            )
        }

        const val SDK_ANDROID_10 = 29
        const val SDK_ANDROID_12 = 31
        const val SDK_ANDROID_13 = 33
    }
}

/** How much attention a version gets. Both tiers run every feature. */
enum class SupportTier {
    /** Android 10–16: tested on every change, held to the iOS standard. */
    Polished,

    /** Android 8–9: works, with the fallbacks noted on each capability. */
    Supported,
}

/**
 * How spoken ideas are captured.
 *
 * **There is deliberately no option that sends audio off the phone.** The iOS app promises
 * that audio is transcribed on the device and then discarded, and Android keeps that
 * promise rather than quietly falling back to a cloud recogniser when the private one is
 * missing. Where private recognition is unavailable, the honest alternative is typing.
 */
sealed interface VoiceCapture {

    /** Speech is recognised on the phone. Audio never leaves it. */
    data object PrivateOnDevice : VoiceCapture

    /** Voice is unavailable; capture offers the keyboard and says why. */
    data class TypingOnly(val reason: Reason) : VoiceCapture

    enum class Reason {
        /** Android 8–11 cannot guarantee recognition stays on the phone. */
        OsTooOld,

        /** Android 12+, but this phone has no on-device recognition service. */
        NoOnDeviceRecognizer,
    }

    companion object {
        fun decide(facts: DeviceFacts): VoiceCapture = when {
            facts.sdkInt < DeviceCapabilities.SDK_ANDROID_12 -> TypingOnly(Reason.OsTooOld)
            facts.hasOnDeviceSpeechRecognizer -> PrivateOnDevice
            else -> TypingOnly(Reason.NoOnDeviceRecognizer)
        }
    }
}

/**
 * Raw facts about the device. Pure values, so every decision above is testable on the JVM
 * for any combination of version and hardware without an emulator.
 */
data class DeviceFacts(
    val sdkInt: Int,
    val isLowRamDevice: Boolean,
    /** 0 when unknown. */
    val totalMemoryBytes: Long,
    val hasOnDeviceSpeechRecognizer: Boolean,
)
