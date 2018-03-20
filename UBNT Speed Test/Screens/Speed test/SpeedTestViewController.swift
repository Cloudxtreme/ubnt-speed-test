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
  var status: Status = .start

  @IBOutlet weak var statusLabel: UILabel!
  @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
  @IBOutlet weak var actionButton: UIButton!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.title = "Speed test"
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    actionButton.rx.tap
      .asDriver()
      .drive(onNext: { [unowned self] in
        switch self.status {
        case .start, .showingResults:
          // start
          self.status = .gettingUserLocation
          self.updateUI()

        case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest:
          // cancel
          self.status = .start
          self.updateUI()
        }
      })
      .disposed(by: disposeBag)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    updateUI()
  }

  func updateUI() {
    switch status {
    case .start, .showingResults:
      actionButton.setTitle("Start", for: .normal)
    case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest:
      actionButton.setTitle("Cancel", for: .normal)
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
  enum Status {
    case start
    case gettingUserLocation
    case fetchingServers
    case findingFastestServer
    case performingSpeedTest
    case showingResults

    var description: String {
      switch self {
      case .start:
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
      }
    }

    var shouldAnimateActivityIndicator: Bool {
      switch self {
      case .start, .showingResults:
        return false
      case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest:
        return true
      }
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
