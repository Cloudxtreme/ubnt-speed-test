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

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.title = "Speed test"
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    actionButton.rx.tap
      .asDriver()
      .drive(onNext: { [unowned self] in
        switch try! self.viewModel.status.value() {
        case .start, .showingResults, .failed:
          self.viewModel.start()
        case .fetchingServers, .findingFastestServer, .gettingUserLocation, .performingSpeedTest:
          self.viewModel.stop()
        }
      })
      .disposed(by: disposeBag)

    viewModel.status
      .subscribe(onNext: { [unowned self] status in
          print(status)
          self.updateUI(status)
        }, onError: { error in
          print(error)
        })
      .disposed(by: disposeBag)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    updateUI(try! self.viewModel.status.value())
  }

  func updateUI(_ status: SpeedTestViewModel.Status) {
    switch status {
    case .start, .showingResults, .failed:
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
  static func create(viewModel: SpeedTestViewModel) -> SpeedTestViewController {
    let vc = R.storyboard.main.speedTest()!
    vc.viewModel = viewModel
    return vc
  }
}
