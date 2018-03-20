//
//  Model.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import RxSwift

final class Model {
  let api = SpeedTestAPI(baseURL: URL(string: "http://speedtest.ubncloud.com")!)
}
