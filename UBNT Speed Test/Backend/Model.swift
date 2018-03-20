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

  func fetchClientToken() -> Single<Void> {
    let request = CreateClientToken()

    return api.httpRequest(request)
      .do(onSuccess: { [weak self] response in
        self?.api.token = response.payload.token
      })
      .map { _ in Void() }
      .asObservable()
      .asSingle()
  }

  func fetchAllServers() -> Single<[String]> {
    let request = FetchServers()

    return api.httpRequest(request)
      .map { $0.payload.urls }
      .asObservable()
      .asSingle()
  }
}
