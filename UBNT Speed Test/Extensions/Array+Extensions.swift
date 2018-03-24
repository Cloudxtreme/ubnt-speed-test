//
//  Array+Extensions.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 24/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation

extension Array where Element: SignedInteger {
  var average: Element {
    guard !isEmpty else { return 0 }

    return self.reduce(0, +) / Element(self.count)
  }
}
