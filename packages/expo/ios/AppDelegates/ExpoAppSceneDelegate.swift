// Copyright 2015-present 650 Industries. All rights reserved.

import Foundation
import ExpoModulesCore
import React

#if os(iOS) || os(tvOS)

/**
`UIWindowSceneDelegate` base class for Expo apps. Required by the iOS 27, which
 asserts at launch unless the app adopts the scene-based life cycle.

 Responsibilities:
 - Create the `UIWindow` from the connecting `UIWindowScene` and start React Native into it.
 - Re-feed scene life-cycle, URL, and user-activity events to the existing
   `ExpoAppDelegateSubscriberManager`, so app delegate subscribers keep working unchanged.
 */
@objc(EXExpoAppSceneDelegate)
open class ExpoAppSceneDelegate: UIResponder, UIWindowSceneDelegate {
  open var window: UIWindow?

  open func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else {
      return
    }
    guard let provider = UIApplication.shared.delegate as? ExpoReactNativeFactoryProvider,
      let factory = provider.reactNativeFactory else {
      fatalError(
        "ExpoAppSceneDelegate couldn't start React Native because the app delegate doesn't provide a "
        + "React Native factory. Make sure your AppDelegate conforms to ExpoReactNativeFactoryProvider and "
        + "creates its RCTReactNativeFactory in application(_:didFinishLaunchingWithOptions:)."
      )
    }

    let window = UIWindow(windowScene: windowScene)
    self.window = window

    // launchOptions is nil under the scene life cycle; cold-start URLs/activities arrive via
    // `connectionOptions` and are routed below.
    factory.startReactNative(
      withModuleName: provider.reactNativeFactoryModuleName,
      in: window,
      launchOptions: nil
    )

    // Deep links / universal links.
    Self.route(urls: connectionOptions.urlContexts.map { $0.url })
    connectionOptions.userActivities.forEach { Self.route(userActivity: $0) }
  }

  open func sceneDidDisconnect(_ scene: UIScene) {
    window = nil
  }

  // In the scene lifecycle UIKit no longer calls the app delegate equivalents, so we forward
  // these to the subscriber manager to preserve existing subscriber behavior.

  open func sceneDidBecomeActive(_ scene: UIScene) {
    ExpoAppDelegateSubscriberManager.applicationDidBecomeActive(UIApplication.shared)
  }

  open func sceneWillResignActive(_ scene: UIScene) {
    ExpoAppDelegateSubscriberManager.applicationWillResignActive(UIApplication.shared)
  }

  open func sceneWillEnterForeground(_ scene: UIScene) {
    ExpoAppDelegateSubscriberManager.applicationWillEnterForeground(UIApplication.shared)
  }

  open func sceneDidEnterBackground(_ scene: UIScene) {
    ExpoAppDelegateSubscriberManager.applicationDidEnterBackground(UIApplication.shared)
  }

  open func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    Self.route(urls: URLContexts.map { $0.url })
  }

  open func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    Self.route(userActivity: userActivity)
  }

  /// Pass incoming URLs to both the subscriber manager and `RCTLinkingManager`.
  public static func route(urls: [URL]) {
    for url in urls {
      _ = ExpoAppDelegateSubscriberManager.application(UIApplication.shared, open: url, options: [:])
      RCTLinkingManager.application(UIApplication.shared, open: url, options: [:])
    }
  }

  /// Passes an incoming `NSUserActivity` to both the subscriber manager and `RCTLinkingManager`.
  public static func route(userActivity: NSUserActivity) {
    _ = ExpoAppDelegateSubscriberManager.application(
      UIApplication.shared,
      continue: userActivity,
      restorationHandler: { _ in }
    )
    RCTLinkingManager.application(
      UIApplication.shared,
      continue: userActivity,
      restorationHandler: { _ in }
    )
  }
}

#endif
