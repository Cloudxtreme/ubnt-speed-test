//
//  Model.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import RxSwift
import struct CoreLocation.CLLocationCoordinate2D

final class Model {
  let mainServerAPI = try! SpeedTestAPI(baseURL: URL(string: "http://speedtest.ubncloud.com")!)

  func fetchServers(from coordinates: CLLocationCoordinate2D) -> Observable<[FetchServers.Server]> {
    return self.mainServerAPI.createClientToken()
      .flatMap { [unowned self] _ in
        self.mainServerAPI.fetchAllServers(coordinates: coordinates)
      }
  }
}
