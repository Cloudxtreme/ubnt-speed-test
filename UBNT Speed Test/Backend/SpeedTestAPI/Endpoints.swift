//
//  Endpoints.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import Alamofire
import struct CoreLocation.CLLocationCoordinate2D
import typealias CoreLocation.CLLocationDegrees

struct CreateClientToken: RequestProtocol {
  let method: HTTPMethod = .post
  let path: String = "/api/v1/tokens"
  let payload: Void = ()

  struct ResponsePayload: JSONDecodable {
    var token: String
    var ttl: Int
  }

  typealias Response = JSONDecodableResponse<ResponsePayload>
}

struct FetchServers: RequestProtocol {
  let method: HTTPMethod = .get
  let path: String = "/api/v2/servers"
  let payload: URLParameters

  init(coordinates: CLLocationCoordinate2D?) {
    let arguments = coordinates.map { ["latitude": String($0.latitude), "longitude": String($0.longitude)] } ?? [:]
    payload = URLParameters(parameters: arguments)
  }

  struct Server: JSONDecodable, Equatable {
    let city: String
    let country: String
    let countryCode: String
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    let provider: String
    let speedMbps: Int
    let url: URL

    static func == (lhs: Server, rhs: Server) -> Bool {
      return lhs.city == rhs.city &&
             lhs.country == rhs.country &&
             lhs.countryCode == rhs.countryCode &&
             lhs.latitude == rhs.latitude &&
             lhs.longitude == rhs.longitude &&
             lhs.provider == rhs.provider &&
             lhs.speedMbps == rhs.speedMbps &&
             lhs.url == rhs.url
    }
  }

  struct ResponsePayload: JSONDecodable {
    let servers: [Server]

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      servers = try container.decode([Server].self) // parse list of strings
    }
  }

  typealias Response = JSONDecodableResponse<ResponsePayload>
}

struct DownloadFile: RequestProtocol {
  let method: HTTPMethod = .get
  let path: String = "/download"
  let payload: URLParameters

  init(size: Int) {
    payload = [
      "size": String(size),
    ]
  }

  typealias Response = VoidResponse
}
