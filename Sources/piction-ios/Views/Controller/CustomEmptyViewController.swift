//
//  CustomEmptyViewController.swift
//  PictionSDK
//
//  Created by jhseo on 05/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable

final class CustomEmptyViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var button: UIButton!
}

extension CustomEmptyViewController: ViewModelBindable {

    typealias ViewModel = CustomEmptyViewModel

    func bindViewModel(viewModel: ViewModel) {

        let input = CustomEmptyViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            btnDidTap: button.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .emptyViewStyle
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.emptyImageView.image = style.image
                self.descriptionLabel.text = style.description

                self.button.isHidden = style.buttonTitle == nil
                self.button.setTitle(style.buttonTitle, for: .normal)
                if style.buttonImage != nil {
                    self.button.imageView?.contentMode = .scaleAspectFit
                    self.button.setImage(style.buttonImage, for: .normal)
                }
            })
            .disposed(by: disposeBag)

        output
            .buttonAction
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                switch style {
                case .defaultLogin:
                    self.openSignInViewController()
                default:
                    break
                }
            })
            .disposed(by: disposeBag)
    }
}
