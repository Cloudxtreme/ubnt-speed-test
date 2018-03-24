//
//  TransferSpeedFormatter.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 24/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation

final class TransferSpeedFormatter {
  let formatter = ByteCountFormatter()

  func string(fromBytesPerSecond bytesPerSecond: Int64) -> String {
    return formatter.string(fromByteCount: bytesPerSecond) + "/s"
  }
}
