//
//  SendDonationViewController.swift
//  PictionSDK
//
//  Created by jhseo on 19/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import PictionSDK

final class SendDonationViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var pxlLabel: UILabel!
    @IBOutlet weak var loginIdLabel: UILabel!
    @IBOutlet weak var amountTextField: UITextField!
    @IBOutlet weak var amountUnderlineView: UIView!
    @IBOutlet weak var sendButton: UIButton!
    @IBOutlet weak var sendButtonDescriptionLabel: UILabel! {
            didSet {
                let buttonText = LocalizedStrings.str_sponsorship_amount.localized()+"\n"+LocalizedStrings.str_fee_free.localized()
                let attributedStr = NSMutableAttributedString(string: buttonText)
                attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 18), range: attributedStr.mutableString.range(of: LocalizedStrings.str_sponsorship_amount.localized()))
                attributedStr.addAttribute(NSAttributedString.Key.font, value: UIFont.systemFont(ofSize: 12), range: attributedStr.mutableString.range(of: LocalizedStrings.str_fee_free.localized()))

                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                paragraphStyle.lineSpacing = 4
                attributedStr.addAttribute(NSAttributedString.Key.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: buttonText.count))
                sendButtonDescriptionLabel.attributedText = attributedStr
            }
        }
    @IBOutlet weak var profileImageView: UIImageViewExtension!

    @IBOutlet weak var amountUnderlineHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    private let authSuccessWithPincode = PublishSubject<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardManager.shared.delegate = self
    }

    private func openConfirmDonationViewController(loginId: String, sendAmount: Int) {
        let vc = ConfirmDonationViewController.make(loginId: loginId, sendAmount: sendAmount)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openCheckPincodeViewController() {
        let vc = CheckPincodeViewController.make(style: .check)
        vc.delegate = self
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .present)
        }
    }

    private func errorPopup(message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let okAction = UIAlertAction(title: LocalizedStrings.confirm.localized(), style: .default, handler: { action in
        })
        alert.addAction(okAction)

        present(alert, animated: false, completion: nil)
    }
}

extension SendDonationViewController: ViewModelBindable {
    typealias ViewModel = SendDonationViewModel

    func bindViewModel(viewModel: ViewModel) {
        let input = SendDonationViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            amountTextFieldDidInput: amountTextField.rx.text.orEmpty.asDriver(),
            sendBtnDidTap: sendButton.rx.tap.asDriver(),
            authSuccessWithPincode: authSuccessWithPincode.asDriver(onErrorDriveWith: .empty())
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.amountTextField.becomeFirstResponder()
                let userId = self?.viewModel?.loginId ?? ""
                FirebaseManager.screenName("후원_후원하기_후원금액입력_\(userId)")
            })
            .disposed(by: disposeBag)

        output
            .userInfo
            .drive(onNext: { [weak self] userInfo in
                if let profileImage = userInfo.picture {
                    let userPictureWithIC = "\(profileImage)?w=240&h=240&quality=80&output=webp"
                    if let url = URL(string: userPictureWithIC) {
                        self?.profileImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500"), completed: nil)
                    }
                } else {
                    self?.profileImageView.image = #imageLiteral(resourceName: "img-dummy-userprofile-500-x-500")
                }
                self?.loginIdLabel.text = "@\(userInfo.loginId ?? "")"
            })
            .disposed(by: disposeBag)

        output
            .walletInfo
            .drive(onNext: { [weak self] walletInfo in
                self?.pxlLabel.text = "\(walletInfo.amount.commaRepresentation) PXL " + LocalizedStrings.str_have_pxl_amount.localized()
            })
            .disposed(by: disposeBag)

        output
            .enableSendButton
            .drive(onNext: { [weak self] status in
                self?.sendButton.isEnabled = status
                self?.sendButtonDescriptionLabel.textColor = status ? .white : .pictionGray
                self?.sendButton.backgroundColor = status ? UIColor(r: 51, g: 51, b: 51) : .pictionLightGray

                if status {
                    self?.amountUnderlineHeightConstraint.constant = 3
                    self?.amountUnderlineView.layer.shadowOpacity = 0.2
                    self?.amountUnderlineView.layer.shadowColor = UIColor.pictionBlue.cgColor
                    self?.amountUnderlineView.layer.shadowRadius = 4
                    self?.amountUnderlineView.layer.shadowOffset = CGSize(width: 0, height: 1)
                    self?.amountUnderlineView.layer.masksToBounds = false
                } else {
                    self?.amountUnderlineHeightConstraint.constant = 1
                    self?.amountUnderlineView.layer.shadowOpacity = 0
                    self?.amountUnderlineView.layer.shadowColor = UIColor.clear.cgColor
                    self?.amountUnderlineView.layer.shadowRadius = 0
                    self?.amountUnderlineView.layer.shadowOffset = CGSize(width: 0, height: 0)
                    self?.amountUnderlineView.layer.masksToBounds = true
                }
            })
            .disposed(by: disposeBag)

        output
            .openConfirmDonationViewController
            .drive(onNext: { [weak self] (loginId, sendAmount) in
                self?.openConfirmDonationViewController(loginId: loginId, sendAmount: sendAmount)
            })
            .disposed(by: disposeBag)

        output
            .openCheckPincodeViewController
            .drive(onNext: { [weak self] _ in
                self?.openCheckPincodeViewController()
            })
            .disposed(by: disposeBag)

        output
            .openErrorPopup
            .drive(onNext: { [weak self] message in
                self?.errorPopup(message: message)
            })
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)

        output
            .popToViewController
            .drive(onNext: { [weak self] message in
                self?.navigationController?.popViewController(animated: true)
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)
    }
}

extension SendDonationViewController: KeyboardManagerDelegate {
    func keyboardManager(_ keyboardManager: KeyboardManager, keyboardWillChangeFrame endFrame: CGRect?, duration: TimeInterval, animationCurve: UIView.AnimationOptions) {
        guard let endFrame = endFrame else { return }

        if endFrame.origin.y >= SCREEN_H {
            bottomConstraint.constant = 0
        } else {
            bottomConstraint.constant = endFrame.size.height
        }

        UIView.animate(withDuration: duration, animations: {
            self.view.layoutIfNeeded()
        })
    }
}

extension SendDonationViewController: CheckPincodeDelegate {
    func authSuccess() {
        self.authSuccessWithPincode.onNext(())
    }
}
