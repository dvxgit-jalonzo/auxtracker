//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import auto_updater_macos
import path_provider_foundation
import screen_retriever_macos
import shared_preferences_foundation
import system_idle_macos
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AutoUpdaterMacosPlugin.register(with: registry.registrar(forPlugin: "AutoUpdaterMacosPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SystemIdlePlugin.register(with: registry.registrar(forPlugin: "SystemIdlePlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
