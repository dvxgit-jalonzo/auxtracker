//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import flutter_screen_capture
import path_provider_foundation
import screen_capturer_macos
import screen_retriever_macos
import shared_preferences_foundation
import system_idle_macos
import system_tray
import window_manager

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  FlutterScreenCapturePlugin.register(with: registry.registrar(forPlugin: "FlutterScreenCapturePlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  ScreenCapturerMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenCapturerMacosPlugin"))
  ScreenRetrieverMacosPlugin.register(with: registry.registrar(forPlugin: "ScreenRetrieverMacosPlugin"))
  SharedPreferencesPlugin.register(with: registry.registrar(forPlugin: "SharedPreferencesPlugin"))
  SystemIdlePlugin.register(with: registry.registrar(forPlugin: "SystemIdlePlugin"))
  SystemTrayPlugin.register(with: registry.registrar(forPlugin: "SystemTrayPlugin"))
  WindowManagerPlugin.register(with: registry.registrar(forPlugin: "WindowManagerPlugin"))
}
