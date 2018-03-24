//
//  SpeedTestAPI.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import Alamofire
import RxSwift
import RxCocoa
import RxAlamofire
import struct CoreLocation.CLLocationCoordinate2D

final class SpeedTestAPI {
  let disposeBag = DisposeBag()
  let baseURL: URL

  private(set) var token: String?

  private let sessionManager: SessionManager

  init(baseURL: URL, token: String? = nil) throws {
    self.baseURL = baseURL
    self.sessionManager = SessionManager()
    self.token = token
  }

  func defaultHeaders() -> HTTPHeaders {
    var headers: HTTPHeaders = SessionManager.defaultHTTPHeaders
    headers["Cache-Control"] = "no-cache"
    headers["Accept"] = "application/json"

    if let token = self.token {
      headers["x-auth-token"] = token
      headers["x-test-token"] = token
    }

    return headers
  }

  // * -> JSONDecodable
  private func httpRequest<Request: RequestProtocol, Payload>(_ request: Request) -> Observable<Request.Response>
    where Request.Response == JSONDecodableResponse<Payload> {
      do {
        return try request.createRequest(in: sessionManager, baseURL: baseURL, headers: self.defaultHeaders()).rx
          .responseData()
          .map { response, data -> Request.Response in try Request.Response(payload: data) }
      } catch {
        return Observable.error(error)
      }
  }

  func createClientToken() -> Observable<Void> {
    let request = CreateClientToken()

    return httpRequest(request)
      .do(onNext: { [weak self] response in
        self?.token = response.payload.token
      })
      .map { _ in Void() }
      .asObservable()
  }

  func fetchAllServers(coordinates: CLLocationCoordinate2D? = nil) -> Observable<[FetchServers.Server]> {
    let request = FetchServers(coordinates: coordinates)

    return httpRequest(request)
      .map { $0.payload.servers }
      .asObservable()
  }

  func pingRequest() -> Single<PingRequest.ResponsePayload> {
    let request = PingRequest()

    return httpRequest(request)
      .map { $0.payload }
      .asSingle()
  }

  func startDownloadingHugeFile(size: Int = 20_000_000) -> DataRequest {
    let request = DownloadFile(size: size)
    return request.createRequest(in: sessionManager, baseURL: baseURL, headers: self.defaultHeaders())
  }
}
