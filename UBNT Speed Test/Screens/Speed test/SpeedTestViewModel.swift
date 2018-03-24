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
  let disposeBag = DisposeBag()

  let model: Model
  let status = BehaviorRelay<Status>(value: .readyToTest)

  private weak var speedTestPerformer: SpeedTestPerformer?

  var locationManager = CLLocationManager().tap {
    $0.desiredAccuracy = kCLLocationAccuracyHundredMeters
  }

  init(model: Model) {
    self.model = model
  }

  func start() {
    status.accept(.gettingUserLocation)

    requestForLocationAuthorizationIfNeeded()
      .asObservable()
      .flatMap { [unowned self] _ -> Observable<[CLLocation]> in
        let observable = self.locationManager.rx.didUpdateLocations
        let failObservable = self.locationManager.rx.didFailWithError.flatMap { Observable<[CLLocation]>.error($0) }

        self.locationManager.requestLocation()

        return Observable.merge(observable, failObservable)
      }
      // take only first event to avoid multiple runs of the following test
      .take(1)
      .flatMap { [unowned self] locations -> Observable<[FetchServers.Server]> in
        let location = locations.first!.coordinate
        self.status.accept(.fetchingServers(fromLocation: location))

        return self.model.fetchServers(from: location)
      }
      // limit to first 5
      .map { Array($0[...5]) }
      //
      .flatMap { servers -> Observable<Results> in
        self.status.accept(.findingFastestServer(fromServers: servers))

        return ServerPinger.fastest(from: servers.map { $0.url })
          .map { result in Results(speed: 0, server: servers.first(where: { $0.url == result.url })!, ping: result.ping) }
          .asObservable()
      }
      .flatMap { [unowned self] result -> Observable<Results> in
        self.status.accept(.performingSpeedTest(currentResults: result))

        return Observable.create { observer in
          let localBag = DisposeBag()

          let api = try! SpeedTestAPI(baseURL: result.server.url)
          api.token = self.model.mainServerAPI.token

          let performer = SpeedTestPerformer(api: api)
          performer.currentSpeed
            // calculate current speed only at certain speed, so the user can actually see something
            .buffer(timeSpan: 0.15, count: 1000, scheduler: MainScheduler.instance)
            .map { Results(speed: $0.average, server: result.server, ping: result.ping) }
            .subscribe(onNext: { [unowned self] in
              self.status.accept(.performingSpeedTest(currentResults: $0))
            })
            .disposed(by: localBag)

          performer.averageSpeed
            .map { Results(speed: $0, server: result.server, ping: result.ping) }
            .bind(to: observer)
            .disposed(by: localBag)

          self.speedTestPerformer = performer

          performer.start()

          return Disposables.create {
            performer.stop()
            _ = localBag
          }
        }
      }
      .subscribe(onNext: { result in
        self.status.accept(.showingResults(finalResults: result))
      }, onError: { error in
        self.status.accept(.failed(error: error))
      })
      .disposed(by: disposeBag)
  }

  func stop() {
    speedTestPerformer?.stop()
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
  enum Status: Equatable {
    case readyToTest
    case gettingUserLocation
    case fetchingServers(fromLocation: CLLocationCoordinate2D)
    case findingFastestServer(fromServers: [FetchServers.Server])
    case performingSpeedTest(currentResults: Results)
    case showingResults(finalResults: Results)
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
      case .readyToTest, .showingResults:
        return false
      case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest, .failed:
        return true
      }
    }

    static func == (lhs: Status, rhs: Status) -> Bool {
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

  struct Results: Equatable {
    var speed: Int64 // bytes / s
    var server: FetchServers.Server
    var ping: TimeInterval

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
