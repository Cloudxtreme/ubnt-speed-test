//
//  SpeedTestViewController.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import UIKit

final class SpeedTestViewController: UIViewController {
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.title = "Speed test"
  }
}

extension SpeedTestViewController {
  static func create() -> SpeedTestViewController {
    return R.storyboard.main.speedTest()!
  }
}
