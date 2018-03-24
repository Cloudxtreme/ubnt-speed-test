//
//  SpeedTestViewController.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

final class SpeedTestViewController: UIViewController {
  let disposeBag = DisposeBag()
  private var viewModel: SpeedTestViewModel!

  @IBOutlet weak var statusLabel: UILabel!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var actionButton: UIButton!

  @IBOutlet weak var pingLabel: UILabel!
  @IBOutlet weak var serverNameLabel: UILabel!
  @IBOutlet weak var speedLabel: UILabel!

  private let speedFormatter = TransferSpeedFormatter()
  private let pingFormatter = PingFormatter()

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.title = L.speedTestTitle()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    actionButton.rx.tap
      .asDriver()
      .drive(onNext: { [unowned self] in
        switch self.viewModel.state.value {
        case .readyToTest, .showingResults, .failed:
          self.viewModel.start()
        case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest:
          self.viewModel.stop()
        }
      })
      .disposed(by: disposeBag)

    viewModel.state
      .subscribe(onNext: { [unowned self] status in
          self.updateUI(status)
        }, onError: { error in
          print(error)
        })
      .disposed(by: disposeBag)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    updateUI(viewModel.state.value)
  }

  func updateUI(_ status: SpeedTestViewModel.State) {
    switch status {
    case .readyToTest, .showingResults:
      actionButton.setTitle(L.speedTestStart(), for: .normal)
    case .failed:
      actionButton.setTitle(L.speedTestTryAgain(), for: .normal)
    case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest:
      actionButton.setTitle(L.speedTestStop(), for: .normal)
    }

    switch status {
    case .performingSpeedTest(let currentResults), .showingResults(let currentResults):
      pingLabel.text = pingFormatter.string(from: currentResults.ping)
      serverNameLabel.text = currentResults.server.city
      speedLabel.text = speedFormatter.string(fromBytesPerSecond: currentResults.speed)

    default:
      pingLabel.text = ""
      serverNameLabel.text = ""
      speedLabel.text = ""
    }

    statusLabel.text = status.description

    switch (activityIndicator.isAnimating, status.shouldAnimateActivityIndicator) {
    case (true, false):
      activityIndicator.stopAnimating()
    case (false, true):
      activityIndicator.startAnimating()

    default:
      break
    }
  }
}

extension SpeedTestViewController {
  static func create(viewModel: SpeedTestViewModel) -> SpeedTestViewController {
    let vc = R.storyboard.main.speedTest()!
    vc.viewModel = viewModel
    return vc
  }
}
