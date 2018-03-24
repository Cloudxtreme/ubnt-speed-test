//
//  ServerPinger.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 21/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import GBPing
import RxSwift

final class ServerPinger: NSObject {
  let url: URL
  let numberOfPings: Int = 5

  private let innerPinger = GBPing()
  private var results: [Result] = []
  private var averageResult: Result? {
    guard let url = results.first?.url else { return nil }

    let sum = results.map { $0.ping }.reduce(0, +)
    let avg = sum / Double(results.count)
    return Result(url: url, ping: avg)
  }

  let finish = PublishSubject<Result>()

  init(url: URL) {
    self.url = url

    super.init()

    innerPinger.tap {
      $0.host = url.host
      $0.delegate = self
      $0.pingPeriod = 0.3
    }
  }

  func start() {
    innerPinger.setup { [weak self] success, error in
      guard let weakSelf = self else { return }

      if let error = error {
        weakSelf.finish.onError(error)
      } else {
        print("start pinging \(weakSelf.url)")
        weakSelf.innerPinger.startPinging()
      }
    }
  }

  func stop() {
    innerPinger.stop()
  }

  static func ping(for url: URL) -> Single<Result> {
    return Single.create { single in
      let instance = ServerPinger(url: url)
      instance.start()

      let disposable = instance.finish.asSingle().subscribe(single)

      return Disposables.create {
        instance.stop()
        disposable.dispose()
      }
    }
  }

  static func fastest(from urls: [URL]) -> Single<Result> {
    return Single.create { single in
      let observables = urls.map(self.ping).map { $0.asObservable() }

      return Observable.concat(observables)
        // merge all events into one array
        .buffer(timeSpan: 1000, count: urls.count, scheduler: MainScheduler.instance)
        // filter empty array, because buffer sends two windows, one containing all of the elements and one empty (bug in implementation)
        .filter { !$0.isEmpty }
        .map { $0.min(by: { $0.ping < $1.ping })! }
        .asSingle()
        .subscribe(single)
    }
  }
}

extension ServerPinger {
  struct Result {
    let url: URL
    let ping: TimeInterval

    init(url: URL, ping: TimeInterval) {
      self.url = url
      self.ping = ping
    }

    init(url: URL, from summary: GBPingSummary) {
      self.url = url
      self.ping = summary.receiveDate.timeIntervalSince(summary.sendDate)
    }
  }
}

extension ServerPinger: GBPingDelegate {
  func ping(_ pinger: GBPing!, didFailWithError error: Error!) {
    self.finish.onError(error)
  }

  func ping(_ pinger: GBPing!, didReceiveReplyWith summary: GBPingSummary!) {
    let result = Result(url: self.url, from: summary)
    print("\(result.url), \(result.ping)")
    results.append(result)

    if results.count >= numberOfPings {
      self.stop()

      self.finish.onNext(self.averageResult!)
      self.finish.onCompleted()
    }
  }
}
