//
//  SpeedTestViewController.swift
//  UBNT Speed Test
//
//  Created by Roman Kříž on 20/03/2018.
//  Copyright © 2018 Roman Kříž. All rights reserved.
//

import UIKit
import RxSwift

final class SpeedTestViewController: UIViewController {
  let disposeBag = DisposeBag()
  private var viewModel: SpeedTestViewModel!

  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)

    self.title = "Speed test"
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    viewModel.model.fetchClientToken()
      .flatMap { [unowned self] in
        return self.viewModel.model.fetchAllServers()
      }
      .subscribe(onSuccess: { urls in
        print(urls)
      })
      .disposed(by: disposeBag)
  }
}

extension SpeedTestViewController {
  static func create(viewModel: SpeedTestViewModel) -> SpeedTestViewController {
    let vc = R.storyboard.main.speedTest()!
    vc.viewModel = viewModel
    return vc
  }
}
