//
//  CLLocationCoordinate+Extensions.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 22/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import struct CoreLocation.CLLocationCoordinate2D

extension CLLocationCoordinate2D: Equatable {
  public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
    return lhs.latitude == rhs.latitude &&
           lhs.longitude == rhs.longitude
  }
}
