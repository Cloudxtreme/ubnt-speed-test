//
//  SpeedTestAPI+Helpers.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 24/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import Alamofire

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
