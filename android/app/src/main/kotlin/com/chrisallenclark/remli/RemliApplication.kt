package com.chrisallenclark.remli

import android.app.Application
import com.chrisallenclark.remli.capabilities.AndroidDeviceFacts
import com.chrisallenclark.remli.capabilities.DeviceCapabilities
import com.chrisallenclark.remli.data.IdeaStore
import com.chrisallenclark.remli.data.RemliDatabase
import com.chrisallenclark.remli.design.AppearanceStore

/**
 * Owns the things that live as long as the process: the store, the appearance choice, and
 * what this phone can do. Port of RemliApp.swift's responsibilities.
 */
class RemliApplication : Application() {

    val store: IdeaStore by lazy { IdeaStore(RemliDatabase(this)).also { it.load() } }
    val appearance: AppearanceStore by lazy { AppearanceStore.from(this) }
    val capabilities: DeviceCapabilities by lazy { DeviceCapabilities.from(AndroidDeviceFacts.read(this)) }
}
