//
//  SpeedTestViewModel.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import RxSwift
import RxCocoa
import CoreLocation

final class SpeedTestViewModel {
  var disposeBag = DisposeBag()

  let model: Model
  let state = BehaviorRelay<State>(value: .readyToTest)

  private weak var speedTestPerformer: SpeedTestPerformer?

  var locationManager = CLLocationManager().tap {
    $0.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  init(model: Model) {
    self.model = model
  }

  func start() {
    state.accept(.gettingUserLocation)

    requestForLocationAuthorizationIfNeeded()
      .asObservable()
      // request for device's location
      .flatMap { [unowned self] _ -> Observable<[CLLocation]> in
        let observable = self.locationManager.rx.didUpdateLocations
        let failObservable = self.locationManager.rx.didFailWithError.flatMap { Observable<[CLLocation]>.error($0) }

        self.locationManager.requestLocation()

        return Observable.merge(observable, failObservable)
      }
      // take only first event to avoid multiple runs of the following test
      .take(1)
      // fetch for nearby servers
      .flatMap { [unowned self] locations -> Observable<[FetchServers.Server]> in
        let location = locations.first!.coordinate
        self.state.accept(.fetchingServers(fromLocation: location))

        return self.model.fetchServers(from: location)
      }
      // limit to first 5
      .map { Array($0[...5]) }
      // ping all servers and find the fastest
      .flatMap { servers -> Observable<SpeedResults> in
        self.state.accept(.findingFastestServer(fromServers: servers))

        return ServerPinger.fastest(from: servers.map { $0.url })
          .map { result in SpeedResults(speed: 0, server: servers.first(where: { $0.url == result.url })!, ping: result.ping) }
          .asObservable()
      }
      // perform the speed test
      .flatMap { [unowned self] result -> Observable<SpeedResults> in
        self.state.accept(.performingSpeedTest(currentResults: result))

        return Observable.create { observer in
          let localBag = DisposeBag()

          let api = try! SpeedTestAPI(baseURL: result.server.url, token: self.model.mainServerAPI.token)

          let performer = SpeedTestPerformer(api: api)
          performer.currentSpeed
            // calculate current speed only at certain speed, so the user can actually see something
            .buffer(timeSpan: 0.15, count: 1000, scheduler: MainScheduler.instance)
            .map { SpeedResults(speed: $0.average, server: result.server, ping: result.ping) }
            .subscribe(onNext: { [unowned self] in
              self.state.accept(.performingSpeedTest(currentResults: $0))
            })
            .disposed(by: localBag)

          performer.averageSpeed
            .takeLast(1) // average speed is calculated on every currentSpeed, but we want only the last final item
            .map { SpeedResults(speed: $0, server: result.server, ping: result.ping) }
            .bind(to: observer)
            .disposed(by: localBag)

          self.speedTestPerformer = performer

          performer.start()

          return Disposables.create {
            performer.cancel()
            _ = localBag
          }
        }
      }
      .subscribe(onNext: { result in
        self.state.accept(.showingResults(finalResults: result))
      }, onError: { error in
        self.state.accept(.failed(error: error))
      })
      .disposed(by: disposeBag)
  }

  func cancel() {
    speedTestPerformer?.cancel()
    disposeBag = DisposeBag()
    state.accept(.readyToTest)
  }

  private func requestForLocationAuthorizationIfNeeded() -> Single<Void> {
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
  enum State: Equatable {
    case readyToTest
    case gettingUserLocation
    case fetchingServers(fromLocation: CLLocationCoordinate2D)
    case findingFastestServer(fromServers: [FetchServers.Server])
    case performingSpeedTest(currentResults: SpeedResults)
    case showingResults(finalResults: SpeedResults)
    case failed(error: Error)

    var description: String {
      switch self {
      case .readyToTest:
        return "Ready"
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
      case .readyToTest, .showingResults, .failed:
        return false
      case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest:
        return true
      }
    }

    static func == (lhs: State, rhs: State) -> Bool {
      switch (lhs, rhs) {
      case (.readyToTest, .readyToTest):
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

  struct SpeedResults: Equatable {
    var speed: Int64 // bytes / s
    var server: FetchServers.Server
    var ping: TimeInterval

    static func == (lhs: SpeedResults, rhs: SpeedResults) -> Bool {
      return lhs.speed == rhs.speed &&
             lhs.server == rhs.server &&
             lhs.ping == rhs.ping
    }
  }

  enum Errors: Error, LocalizedError {
    case noAccessToLocation

    var errorDescription: String? {
      switch self {
      case .noAccessToLocation:
        return "Application does not have access to device's location, go to Settings -> Privacy -> Location Services -> UBNT Speed Test and enable them."
      }
    }
  }
}
