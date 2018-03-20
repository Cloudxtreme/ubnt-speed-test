//
//  Endpoints.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import Alamofire

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
  let path: String = "/api/v1/servers"
  let payload: Void = ()

  struct ResponsePayload: JSONDecodable {
    let urls: [String]

    init(from decoder: Decoder) throws {
      let container = try decoder.singleValueContainer()
      urls = try container.decode([String].self) // parse list of strings
    }
  }

  typealias Response = JSONDecodableResponse<ResponsePayload>
}
