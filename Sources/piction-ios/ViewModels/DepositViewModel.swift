//
//  DepositViewModel.swift
//  PictionSDK
//
//  Created by jhseo on 13/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import RxSwift
import RxCocoa
import PictionSDK

final class DepositViewModel: InjectableViewModel {

    typealias Dependency = (
        FirebaseManagerProtocol
    )

    private let firebaseManager: FirebaseManagerProtocol

    init(dependency: Dependency) {
        (firebaseManager) = dependency
    }

    var loadRetryTrigger = PublishSubject<Void>()

    struct Input {
        let viewWillAppear: Driver<Void>
        let copyBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let userInfo: Driver<UserModel>
        let walletInfo: Driver<WalletModel>
        let copyAddress: Driver<String>
        let showErrorPopup: Driver<Void>
        let activityIndicator: Driver<Bool>
    }

    func build(input: Input) -> Output {
        let firebaseManager = self.firebaseManager

        let viewWillAppear = input.viewWillAppear
            .do(onNext: { _ in
                firebaseManager.screenName("마이페이지_입금")
            })

        let initialLoad = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
        let loadRetry = loadRetryTrigger.asDriver(onErrorDriveWith: .empty())

        let userInfoAction = Driver.merge(initialLoad, loadRetry)
            .map { UserAPI.me }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let userInfoSuccess = userInfoAction.elements
            .map { try? $0.map(to: UserModel.self) }
            .flatMap(Driver.from)

        let walletInfoAction = Driver.merge(initialLoad, loadRetry)
            .map { WalletAPI.get }
            .map(PictionSDK.rx.requestAPI)
            .flatMap(Action.makeDriver)

        let walletInfoSuccess = walletInfoAction.elements
            .map { try? $0.map(to: WalletModel.self) }
            .flatMap(Driver.from)

        let walletInfoError = walletInfoAction.error
            .map { _ in Void() }

        let showErrorPopup = walletInfoError

        let copyAddress = input.copyBtnDidTap
            .withLatestFrom(walletInfoSuccess)
            .map { $0.publicKey }
            .flatMap(Driver.from)

        let activityIndicator = walletInfoAction.isExecuting

        return Output(
            viewWillAppear: viewWillAppear,
            userInfo: userInfoSuccess,
            walletInfo: walletInfoSuccess,
            copyAddress: copyAddress,
            showErrorPopup: showErrorPopup,
            activityIndicator: activityIndicator
        )
    }
}
