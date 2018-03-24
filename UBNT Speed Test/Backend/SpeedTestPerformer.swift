//
//  SpeedTestPerformer.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 23/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import Foundation
import RxSwift
import Alamofire
import RxAlamofire
import RxCocoa

final class SpeedTestPerformer {
  private var disposeBag = DisposeBag()
  private let api: SpeedTestAPI

  private var currentRequest: DataRequest?

  private var fileBytesTransfered: Int64 = 0
  private var lastSampleDate: Date?

  private var allBytesTransfered: Int64 = 0
  private var allStartDate: Date?

  let testingTimeInterval: TimeInterval = 15

  let currentSpeed = BehaviorSubject<Int64>(value: 0)
  let averageSpeed = BehaviorSubject<Int64>(value: 0)

  init(api: SpeedTestAPI) {
    self.api = api
  }

  func start() {
    allBytesTransfered = 0
    allStartDate = nil
    startDownloadingFile()

    Observable<Void>.just(()).delay(testingTimeInterval, scheduler: MainScheduler.instance)
      .subscribe(onNext: { [unowned self] in
        self.stop()
      })
      .disposed(by: disposeBag)
  }

  func stop() {
    self.currentRequest?.cancel()
    self.currentRequest = nil

    self.disposeBag = DisposeBag()

    self.currentSpeed.onCompleted()
    self.averageSpeed.onCompleted()
  }

  private func startDownloadingFile() {
    fileBytesTransfered = 0
    lastSampleDate = nil

    let request = self.api.startDownloadingHugeFile()
    request.rx.progress()
      .subscribe(onNext: { [unowned self] progress in
        let now = Date()

        if self.allStartDate == nil {
          self.allStartDate = now
        }

        guard let lastSampleDate = self.lastSampleDate else {
          self.lastSampleDate = now
          return
        }

        let thisSampleBytes = progress.bytesWritten - self.fileBytesTransfered
        guard thisSampleBytes != 0 else { return }
        self.fileBytesTransfered = progress.bytesWritten
        self.allBytesTransfered += thisSampleBytes

        self.currentSpeed.onNext(self.calculateSpeed(from: lastSampleDate, to: now, bytesTransfered: thisSampleBytes))
        self.averageSpeed.onNext(self.calculateAverageSpeed())

        self.lastSampleDate = now
      }, onCompleted: { [unowned self] in
        self.startDownloadingFile()
      })
      .disposed(by: disposeBag)

    self.currentRequest = request
  }

  private func calculateSpeed(from: Date, to: Date, bytesTransfered: Int64) -> Int64 {
    let diff = to.timeIntervalSince(from)
    let speed = Double(bytesTransfered) / diff
    return Int64(speed)
  }

  private func calculateAverageSpeed() -> Int64 {
    guard let startDate = self.allStartDate else {
      return 0
    }

    return calculateSpeed(from: startDate, to: Date(), bytesTransfered: self.allBytesTransfered)
  }
}
