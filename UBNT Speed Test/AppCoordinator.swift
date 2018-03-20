//
//  AppCoordinator.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import UIKit

final class AppCoordinator {
  var model: Model
  let rootViewController: UIViewController

  init(model: Model) {
    self.model = model
    self.rootViewController = UINavigationController(rootViewController: SpeedTestViewController.create())
  }
}
