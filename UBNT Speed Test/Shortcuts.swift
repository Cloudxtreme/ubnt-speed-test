//
//  Shortcuts.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation

extension NSObjectProtocol {
  @discardableResult
  func tap(_ block: (Self) -> Void) -> Self {
    block(self)
    return self
  }
}
