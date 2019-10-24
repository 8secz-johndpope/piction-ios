//
//  SearchViewController.swift
//  PictionView
//
//  Created by jhseo on 09/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

enum SearchBySection {
    case Section(title: String, items: [SearchItemType])
}

extension SearchBySection: SectionModelType {
    typealias Item = SearchItemType

    var items: [SearchItemType] {
        switch self {
        case .Section(_, items: let items):
            return items.map { $0 }
        }
    }

    init(original: SearchBySection, items: [Item]) {
        switch original {
        case .Section(title: let title, _):
            self = .Section(title: title, items: items)
        }
    }
}

enum SearchItemType {
    case project(item: ProjectModel)
    case tag(item: TagModel)
}

final class SearchViewController: UIViewController {
    var disposeBag = DisposeBag()

    private let searchText = PublishSubject<String>()
    @IBOutlet weak var segmentedControl: UISegmentedControl!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var emptyView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardManager.shared.delegate = self
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SearchBySection> {
        let dataSource = RxTableViewSectionedReloadDataSource<SearchBySection>(
            configureCell: { dataSource, tableView, indexPath, model in
                switch dataSource[indexPath] {
                case .project(let project):
                    let cell: SearchProjectTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: project)
                    return cell
                case .tag(let tag):
                    let cell: SearchTagTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                    cell.configure(with: tag)
                    return cell
                }
        })
        return dataSource
    }

    private func openProjectViewController(uri: String) {
        let vc = ProjectViewController.make(uri: uri)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func openTagResultProjectViewController(tag: String) {
        let vc = TagResultProjectViewController.make(tag: tag)
        if let topViewController = UIApplication.topViewController() {
            topViewController.openViewController(vc, type: .push)
        }
    }

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = 350
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }
}

extension SearchViewController: ViewModelBindable {
    typealias ViewModel = SearchViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.addInfiniteScroll { [weak self] tableView in
            self?.viewModel?.loadTrigger.onNext(())
        }
        tableView.setShouldShowInfiniteScrollHandler { [weak self] _ in
            return self?.viewModel?.shouldInfiniteScroll ?? false
        }

        let input = SearchViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            searchText: searchText.asDriver(onErrorDriveWith: .empty()).throttle(0.5),
            segmentedControlDidChange: segmentedControl.rx.selectedSegmentIndex.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
            })
            .disposed(by: disposeBag)

        output
            .setPlaceHolder
            .drive(onNext: { menu in
                if menu == 0 {
                    UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizedStrings.hint_project_search.localized()
                } else {
                    UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizedStrings.hint_tag_search.localized()
                }
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { _ in
                UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizedStrings.hint_project_and_tag_search.localized()
            })
            .disposed(by: disposeBag)

        output
            .menuChanged
            .drive(onNext: { menu in
                if menu == 0 {
                    UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizedStrings.hint_project_search.localized()
                } else {
                    UIApplication.topViewController()?.navigationItem.searchController?.searchBar.placeholder = LocalizedStrings.hint_tag_search.localized()
                }
            })
            .disposed(by: disposeBag)

        output
            .searchList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [$0] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .searchList
            .drive(onNext: { [weak self] _ in
                self?.tableView.layoutIfNeeded()
                self?.tableView.finishInfiniteScroll()
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                switch dataSource[indexPath] {
                case .project(let project):
                    self?.openProjectViewController(uri: project.uri ?? "")
                case .tag(let tag):
                    self?.openTagResultProjectViewController(tag: tag.name ?? "")
                }
            })
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)
    }
}

extension SearchViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchController.searchResultsController?.view.isHidden = false
        guard let text = searchController.searchBar.text else { return }
        self.searchText.onNext(text)
    }
}

extension SearchViewController: KeyboardManagerDelegate {
    func keyboardManager(_ keyboardManager: KeyboardManager, keyboardWillChangeFrame endFrame: CGRect?, duration: TimeInterval, animationCurve: UIView.AnimationOptions) {
        guard let endFrame = endFrame else { return }

        if endFrame.origin.y >= SCREEN_H {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        } else {
            tableView.contentInset = UIEdgeInsets(top: 0, left: 0, bottom: endFrame.size.height - (UIApplication.topViewController()?.tabBarController?.tabBar.frame.size.height ?? 0), right: 0)
        }

        UIView.animate(withDuration: duration, animations: {
            self.view.layoutIfNeeded()
        })
    }
}
