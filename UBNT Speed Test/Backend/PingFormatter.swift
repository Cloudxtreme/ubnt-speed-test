//
//  PingFormatter.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 24/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation

final class PingFormatter {
  let formatter = NumberFormatter().tap {
    $0.allowsFloats = false
    $0.positiveSuffix = " ms"
  }

  func string(from interval: TimeInterval) -> String {
    return formatter.string(from: NSNumber(value: interval * 1_000))!
  }
}
