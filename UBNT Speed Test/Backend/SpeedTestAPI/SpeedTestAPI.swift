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
import RxAlamofire
import RxStarscream

final class SpeedTestAPI {
  let baseURL: URL
  let sessionManager: SessionManager

  var token: String?

  init(baseURL: URL) {
    self.baseURL = baseURL
    self.sessionManager = SessionManager()
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
  private func httpRequest<Request: RequestProtocol, Payload>(_ request: Request) -> Single<Request.Response>
    where Request.Response == JSONDecodableResponse<Payload> {

      do {
        return try request.createRequest(in: sessionManager, baseURL: baseURL, headers: self.defaultHeaders()).rx
          .responseData()
          .map { response, data -> Request.Response in try Request.Response(payload: data) }
          .asSingle()
      } catch {
        return Single.error(error)
      }
  }

  func createClientToken() -> Single<Void> {
    let request = CreateClientToken()

    return httpRequest(request)
      .do(onSuccess: { [weak self] response in
        self?.token = response.payload.token
      })
      .map { _ in Void() }
      .asObservable()
      .asSingle()
  }

  func fetchAllServers() -> Single<[FetchServers.Server]> {
    let request = FetchServers(coordinates: nil)

    return httpRequest(request)
      .map { $0.payload.servers }
      .asObservable()
      .asSingle()
  }
}

protocol JSONEncodable: Encodable { }
protocol JSONDecodable: Decodable { }

struct JSONDecodableResponse<T: JSONDecodable>: ResponseProtocol {
  let payload: T

  init(payload json: Data) throws {
    let jsonDecoder = JSONDecoder()
    payload = try jsonDecoder.decode(T.self, from: json)
  }
}

protocol ResponseProtocol {
  associatedtype PayloadType

  init(payload: PayloadType) throws
}

protocol RequestProtocol {
  associatedtype Response: ResponseProtocol
  associatedtype PayloadType

  var path: String { get }
  var method: HTTPMethod { get }

  var payload: PayloadType { get }

  func createRequest(in sessionManager: SessionManager, baseURL: URL, headers: HTTPHeaders?) throws -> DataRequest
}

struct VoidResponse: ResponseProtocol {
  typealias PayloadType = Void

  init(payload: PayloadType) throws { }

  init() { }
}

/// Use this struct as Request's PayloadType for setting parameters to URL as part of query
struct URLParameters {
  var parameters: [String: String]
}
extension URLParameters: ExpressibleByDictionaryLiteral {
  init(dictionaryLiteral elements: (String, String)...) {
    var params: [String: String] = [:]
    elements.forEach {
      params[$0] = $1
    }
    parameters = params
  }
}

extension RequestProtocol where PayloadType == Void {
  func createRequest(in sessionManager: SessionManager, baseURL: URL, headers: HTTPHeaders?) -> DataRequest {
    let wholeURL = baseURL.appendingPathComponent(path)
    return sessionManager.request(wholeURL, method: self.method, headers: headers)
  }
}

extension RequestProtocol where PayloadType == URLParameters {
  func createRequest(in sessionManager: SessionManager, baseURL: URL, headers: HTTPHeaders?) -> DataRequest {
    let wholeURL = baseURL.appendingPathComponent(path)
    return sessionManager.request(wholeURL, method: self.method, parameters: self.payload.parameters,
                                  encoding: URLEncoding.default, headers: headers)
  }
}

extension RequestProtocol where PayloadType: JSONEncodable {
  func createRequest(in sessionManager: SessionManager, baseURL: URL, headers: HTTPHeaders?) throws -> DataRequest {
    let wholeURL = baseURL.appendingPathComponent(path)
    var headers = headers ?? [:]
    if !headers.keys.contains("Content-Type") {
      headers["Content-Type"] = "application/json"
    }

    let encoder = JSONEncoder()
    let data = try encoder.encode(self.payload)

    return sessionManager.upload(data, to: wholeURL, method: self.method, headers: headers)
  }
}
