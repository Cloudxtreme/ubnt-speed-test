//
//  Shortcuts.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation

extension NSObjectProtocol {
  /**
   Method that allows to use something like Factory pattern
   */
  @discardableResult
  func tap(_ block: (Self) -> Void) -> Self {
    block(self)
    return self
  }
}

typealias L = R.string.localizable
