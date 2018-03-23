//
//  SpeedTestViewModel.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import RxSwift
import CoreLocation

final class SpeedTestViewModel {
  let disposeBag = DisposeBag()

  let model: Model
  let status = BehaviorSubject<Status>(value: .initial)

  var locationManager = CLLocationManager().tap {
    $0.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  init(model: Model) {
    self.model = model
  }

  func start() {
    status.onNext(.gettingUserLocation)




    requestForLocationAuthorization()
      .asObservable()
      .flatMap { [unowned self] _ -> Observable<[CLLocation]> in
        let observable = self.locationManager.rx.didUpdateLocations
        let failObservable = self.locationManager.rx.didFailWithError.flatMap { Observable<[CLLocation]>.error($0) }

        self.locationManager.requestLocation()

        return Observable.merge(observable, failObservable)
      }
      .flatMap { [unowned self] locations -> Observable<[FetchServers.Server]> in
        let location = locations.first!.coordinate
        print("did find location \(location)")

        self.status.onNext(.fetchingServers(fromLocation: location))
        return self.model.fetchServers(from: location)
      }
      // limit to first 5
      .map { Array($0[...5]) }
      //
      .flatMap { servers -> Observable<FetchServers.Server> in
        self.status.onNext(.findingFastestServer(fromServers: servers))

        return ServerPinger.fastest(from: servers.map { $0.url })
          .map { result in servers.first(where: { $0.url == result.url })! }
          .asObservable()
      }
      .subscribe(onNext: { server in
        self.status.onNext(.performingSpeedTest(currentResults: Results(speed: 0, server: server, ping: .nan)))
      }, onError: { error in
        self.status.onNext(.failed(error: error))
      })
      .disposed(by: disposeBag)
  }

  func stop() {
    
  }

  private func requestForLocationAuthorization() -> Single<Void> {
    return Single.create { [unowned self] single in
      switch CLLocationManager.authorizationStatus() {
      case .authorizedAlways, .authorizedWhenInUse, .denied, .restricted:
        single(self.validateStatus(CLLocationManager.authorizationStatus()))

      case .notDetermined:
        self.locationManager.rx.didChangeAuthorizationStatus
          .subscribe(onNext: { status in
            single(self.validateStatus(status))
          })
          .disposed(by: self.disposeBag)

        self.locationManager.requestWhenInUseAuthorization()
      }

      return Disposables.create()
    }
  }

  private func validateStatus(_ status: CLAuthorizationStatus) -> SingleEvent<Void> {
    if [.authorizedAlways, .authorizedWhenInUse].contains(status) {
      return .success(())
    } else {
      return .error(Errors.noAccessToLocation)
    }
  }
}

extension SpeedTestViewModel {
  enum Status: Equatable {
    case initial
    case gettingUserLocation
    case fetchingServers(fromLocation: CLLocationCoordinate2D)
    case findingFastestServer(fromServers: [FetchServers.Server])
    case performingSpeedTest(currentResults: Results)
    case showingResults(finalResults: Results)
    case failed(error: Error)

    var description: String {
      switch self {
      case .initial:
        return ""
      case .gettingUserLocation:
        return "Getting current location"
      case .fetchingServers:
        return "Fetching nearby servers"
      case .findingFastestServer:
        return "Resolving fastest server"
      case .performingSpeedTest:
        return "Performing speed test"
      case .showingResults:
        return ""
      case .failed(let error):
        return error.localizedDescription
      }
    }

    var shouldAnimateActivityIndicator: Bool {
      switch self {
      case .initial, .showingResults:
        return false
      case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest, .failed:
        return true
      }
    }

    static func == (lhs: Status, rhs: Status) -> Bool {
      switch (lhs, rhs) {
      case (.initial, .initial):
        return true
      case (.gettingUserLocation, .gettingUserLocation):
        return true
      case let (.fetchingServers(lhsLocation), .fetchingServers(rhsLocation)):
        return lhsLocation == rhsLocation
      case let (.findingFastestServer(lhsServers), .findingFastestServer(rhsServers)):
        return lhsServers == rhsServers
      case let (.performingSpeedTest(lhsResults), .performingSpeedTest(rhsResult)):
        return lhsResults == rhsResult
      case let (.showingResults(lhsResults), .showingResults(rhsResults)):
        return lhsResults == rhsResults
      case let (.failed(lhsError), .failed(rhsError)):
        return lhsError.localizedDescription == rhsError.localizedDescription // `Error` is not equatable

      default:
        return false
      }
    }
  }

  struct Results: Equatable {
    var speed: Int // bytes / s
    var server: FetchServers.Server
    var ping: TimeInterval // ms

    static func == (lhs: Results, rhs: Results) -> Bool {
      return lhs.speed == rhs.speed &&
             lhs.server == rhs.server &&
             lhs.ping == rhs.ping
    }
  }

  enum Errors: Error {
    case noAccessToLocation
  }
}
