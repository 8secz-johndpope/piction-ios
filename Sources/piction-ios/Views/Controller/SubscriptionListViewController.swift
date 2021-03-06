//
//  SubscriptionListViewController.swift
//  PictionView
//
//  Created by jhseo on 25/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import UIScrollView_InfiniteScroll
import PictionSDK

final class SubscriptionListViewController: UIViewController {
    var disposeBag = DisposeBag()

    var emptyView = UIView(frame: CGRect(x: 0, y: 0, width: SCREEN_W, height: 0))
    private var refreshControl = UIRefreshControl()

    @IBOutlet weak var collectionView: UICollectionView! {
        didSet {
            collectionView.isScrollEnabled = false
            collectionView.refreshControl = refreshControl
            collectionView.registerReusableView(ReuseCollectionReusableView.self, kind: .footer)
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        emptyView.frame.size.height = visibleHeight
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
        self.collectionView.reloadData()
    }

    private func configureDataSource() -> RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>> {
        return RxCollectionViewSectionedReloadDataSource<SectionModel<String, ProjectModel>>(
            configureCell: { dataSource, collectionView, indexPath, model in
                let cell: SubscriptionListCollectionViewCell = collectionView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        },
        configureSupplementaryView: { [weak self] (dataSource, collectionView, kind, indexPath) in
            guard let `self` = self else { return UICollectionReusableView() }
            if (kind == UICollectionView.elementKindSectionFooter) {
                let reusableView = collectionView.dequeueReusableView(ReuseCollectionReusableView.self, indexPath: indexPath, kind: .footer)

                _ = reusableView.subviews.map { $0.removeFromSuperview() }
                reusableView.addSubview(self.emptyView)
                return reusableView
            }
            return UICollectionReusableView()
        })
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()

        if let flowLayout = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            let cellCount: CGFloat = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiom.pad && view.frame.size.width == UIScreen.main.bounds.size.width ? 4 : 2
            let width = (view.frame.size.width - 40 - (cellCount - 1) * 7) / cellCount
            let height = width + 44
            flowLayout.itemSize = CGSize(width: width, height: height)
            flowLayout.invalidateLayout()
        }
        emptyView.frame.size.width = view.frame.size.width
        emptyView.frame.size.height = visibleHeight
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setInfiniteScrollStyle()
    }

    private func setInfiniteScrollStyle() {
        if #available(iOS 12.0, *) {
            if self.traitCollection.userInterfaceStyle == .dark {
                collectionView.infiniteScrollIndicatorStyle = .white
            } else {
                collectionView.infiniteScrollIndicatorStyle = .gray
            }
        }
    }
}

extension SubscriptionListViewController: ViewModelBindable {
    typealias ViewModel = SubscriptionListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        collectionView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadNextTrigger.onNext(())
        }
        collectionView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = SubscriptionListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath:
            collectionView.rx.itemSelected.asDriver(),
            refreshControlDidRefresh: refreshControl.rx.controlEvent(.valueChanged).asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: false)
                self?.setInfiniteScrollStyle()
            })
            .disposed(by: disposeBag)

        output
            .subscriptionList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
            })
            .drive { $0 }
            .map { [SectionModel(model: "", items: $0)] }
            .bind(to: collectionView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .subscriptionList
            .drive(onNext: { [weak self] subscriptions in
                self?.collectionView.isScrollEnabled = true
                self?.collectionView.layoutIfNeeded()
                self?.collectionView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.collectionView.isScrollEnabled = style != .defaultLogin
                Toast.loadingActivity(false)
                self.collectionView.contentOffset = CGPoint(x: 0, y: -self.statusHeight-self.largeTitleNavigationHeight)
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

        output
            .openProjectViewController
            .drive(onNext: { [weak self] indexPath in
                guard let uri = dataSource[indexPath].uri else { return }
                self?.openProjectViewController(uri: uri)
            })
            .disposed(by: disposeBag)

        output
            .isFetching
            .drive(refreshControl.rx.isRefreshing)
            .disposed(by: disposeBag)

        output
            .activityIndicator
            .drive(onNext: { status in
                Toast.loadingActivity(status)
            })
            .disposed(by: disposeBag)

        output
            .showErrorPopup
            .drive(onNext: { [weak self] in
                self?.collectionView.finishInfiniteScroll()
                Toast.loadingActivity(false)
                self?.showPopup(
                    title: LocalizedStrings.popup_title_network_error.localized(),
                    message: LocalizedStrings.msg_api_internal_server_error.localized(),
                    action: LocalizedStrings.retry.localized()) { [weak self] in
                        self?.viewModel?.loadRetryTrigger.onNext(())
                    }
            })
            .disposed(by: disposeBag)

        output
            .refreshSession
            .drive(onNext: { [weak self] in
                self?.navigationController?.popToRootViewController(animated: false)
            })
            .disposed(by: disposeBag)
    }
}

extension SubscriptionListViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, referenceSizeForFooterInSection section: Int) -> CGSize {
        if self.emptyView.subviews.count > 0 {
            return CGSize(width: SCREEN_W, height: emptyView.frame.size.height)
        } else {
            return CGSize.zero
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        if self.emptyView.subviews.count > 0 {
            return UIEdgeInsets.zero
        } else {
            return UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        }
    }
}

