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
import Starscream
import RxStarscream
import struct CoreLocation.CLLocationCoordinate2D

final class SpeedTestAPI {
  let disposeBag = DisposeBag()

  let baseURL: URL
  let sessionManager: SessionManager

  let websocketBaseURL: URL
  var websocketConnection: WebSocket?
  let websocketConnected = BehaviorRelay<Bool>(value: false)

  let statMesssageReceived = PublishSubject<StatMessage>()

  var token: String?

  var downloadHugeFile: DataRequest?

  init(baseURL: URL) throws {
    self.baseURL = baseURL
    self.websocketBaseURL = try SpeedTestAPI.websocketURL(for: baseURL)
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

  private func wsConnect(path: String) -> WebSocket {
    var urlComponents = URLComponents(url: websocketBaseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
    urlComponents.queryItems = [URLQueryItem(name: "token", value: self.token)]
    let request = try! URLRequest(url: try! urlComponents.asURL(), method: .get)

    return WebSocket(request: request)
  }

  func connectWebsocket() -> Single<Void> {
    guard websocketConnection == nil else { return Single.just(()) }

    return Single.create { single in
      let socket = self.wsConnect(path: "/connect")
      socket.connect()

      socket.rx.response
        .debug()
        .subscribe(onNext: { event in
          print(event)
          //let decoder = JSONDecoder()
          //let message = try? decoder.decode(StatMessage.self, from: text.data(using: .utf8)!)
          //if let message = message {
          //  self.statMesssageReceived.onNext(message)
          //}
        })
        .disposed(by: self.disposeBag)
      
      socket.rx.connected
        .debug()
        .subscribe(onNext: { [unowned self] connected in
          if connected {
            single(.success(Void()))
          } else {
            self.websocketConnection = nil
          }
          }, onError: { error in
            print(error)
        })
        .disposed(by: self.disposeBag)



      self.websocketConnection = socket

      return Disposables.create {}
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

  static func websocketURL(for url: URL) throws -> URL {
    var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!

    switch components.scheme {
    case "https"?:
      components.scheme = "wss"
    default:
      components.scheme = "ws"
    }

    return try components.asURL()
  }
}

extension SpeedTestAPI {
  struct StatMessage: JSONDecodable {
    var type: String

    var tx: Int
    var rx: Int
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
