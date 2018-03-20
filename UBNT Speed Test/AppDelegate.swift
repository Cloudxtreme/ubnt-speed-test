//
//  AppDelegate.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import UIKit

#if DEBUG
  import AlamofireNetworkActivityLogger
#endif

@UIApplicationMain
class AppDelegate: UIResponder {
  var window: UIWindow?
  let model: Model
  let appCoordinator: AppCoordinator

  override init() {
    self.model = Model()
    self.appCoordinator = AppCoordinator(model: model)

    super.init()
  }
}

extension AppDelegate: UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

    #if DEBUG
      NetworkActivityLogger.shared.startLogging()
      NetworkActivityLogger.shared.level = .debug
    #endif

    window = UIWindow(frame: UIScreen.main.bounds).tap {
      $0.rootViewController = appCoordinator.rootViewController
      $0.makeKeyAndVisible()
    }

    return true
  }
}
