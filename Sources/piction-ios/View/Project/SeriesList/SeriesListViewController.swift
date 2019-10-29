//
//  SeriesListViewController.swift
//  piction-ios
//
//  Created by jhseo on 2019/10/25.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import ViewModelBindable
import RxDataSources
import PictionSDK

protocol SeriesListDelegate: class {
    func selectSeries(with series: SeriesModel?)
}

final class SeriesListViewController: UIViewController {
    var disposeBag = DisposeBag()

    @IBOutlet weak var emptyView: UIView!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var closeButton: UIBarButtonItem!
    @IBOutlet weak var createButton: UIBarButtonItem!

    weak var delegate: SeriesListDelegate?

    private let updateSeries = PublishSubject<(String, SeriesModel?)>()
    private let contextualAction = PublishSubject<(UIContextualAction.Style, IndexPath)>()
    private let deleteConfirm = PublishSubject<Int>()

    private func embedCustomEmptyViewController(style: CustomEmptyViewStyle) {
        _ = emptyView.subviews.map { $0.removeFromSuperview() }
        emptyView.frame.size.height = getVisibleHeight()
        let vc = CustomEmptyViewController.make(style: style)
        embed(vc, to: emptyView)
    }

    private func configureDataSource() -> RxTableViewSectionedReloadDataSource<SectionModel<String, SeriesModel>> {
        return RxTableViewSectionedReloadDataSource<SectionModel<String, SeriesModel>>(
            configureCell: { dataSource, tableView, indexPath, model in
                let cell: SeriesListTableViewCell = tableView.dequeueReusableCell(forIndexPath: indexPath)
                cell.configure(with: model)
                return cell
        }, canEditRowAtIndexPath: { (_, _) in
            return FEATURE_EDITOR
        })
    }

    private func openDeleteConfirmPopup(seriesId: Int) {
        let alertController = UIAlertController(
            title: "시리즈를 삭제하시겠습니까?",
            message: nil,
            preferredStyle: UIAlertController.Style.alert)

            let deleteAction = UIAlertAction(
                title: "삭제",
                style: UIAlertAction.Style.destructive,
                handler: { [weak self] action in
                    self?.deleteConfirm.onNext(seriesId)
                })

            let cancelAction = UIAlertAction(
                title: "취소",
                style:UIAlertAction.Style.cancel,
                handler:{ action in
                })

            alertController.addAction(deleteAction)
            alertController.addAction(cancelAction)

            present(alertController, animated: true, completion: nil)
    }

    private func openUpdateSeriesPopup(series: SeriesModel?) {
        let alertController = UIAlertController(
            title: series == nil ? "새 시리즈 추가" : "시리즈 수정",
            message: nil,
            preferredStyle: UIAlertController.Style.alert)

        alertController.addTextField(configurationHandler: { textField in
            textField.clearButtonMode = UITextField.ViewMode.always
            textField.text = series == nil ? "" : series?.name ?? ""
        })

        let insertAction = UIAlertAction(
            title: series == nil ? "생성" : "수정",
            style: UIAlertAction.Style.default,
            handler: { [weak self] action in
                guard let textFields = alertController.textFields else {
                    return
                }
                self?.updateSeries.onNext((textFields[0].text ?? "", series))
            })

        let cancelAction = UIAlertAction(
            title: "취소",
            style:UIAlertAction.Style.cancel,
            handler:{ action in
            })

        alertController.addAction(insertAction)
        alertController.addAction(cancelAction)

        present(alertController, animated: true, completion: nil)
    }
}

extension SeriesListViewController: ViewModelBindable {
    typealias ViewModel = SeriesListViewModel

    func bindViewModel(viewModel: ViewModel) {
        let dataSource = configureDataSource()

        tableView.rx.setDelegate(self)
            .disposed(by: disposeBag)

        let input = SeriesListViewModel.Input(
            viewWillAppear: rx.viewWillAppear.asDriver(),
            viewWillDisappear: rx.viewWillDisappear.asDriver(),
            selectedIndexPath: tableView.rx.itemSelected.asDriver(),
            createBtnDidTap: createButton.rx.tap.asDriver(),
            contextualAction: contextualAction.asDriver(onErrorDriveWith: .empty()),
            deleteConfirm: deleteConfirm.asDriver(onErrorDriveWith: .empty()),
            updateSeries: updateSeries.asDriver(onErrorDriveWith: .empty()),
            closeBtnDidTap: closeButton.rx.tap.asDriver()
        )

        let output = viewModel.build(input: input)

        output
            .viewWillAppear
            .drive(onNext: { [weak self] _ in
                self?.navigationController?.configureNavigationBar(transparent: false, shadow: true)
                self?.tableView.allowsSelection = self?.delegate != nil
            })
            .disposed(by: disposeBag)

        output
            .viewWillDisappear
            .drive(onNext: { [weak self] _ in
                if let selectedIndexPath = self?.tableView.indexPathForSelectedRow {
                    let series = dataSource[selectedIndexPath]
                    self?.delegate?.selectSeries(with: series)
                } else {
                    self?.delegate?.selectSeries(with: nil)
                }
            })
            .disposed(by: disposeBag)

        output
            .seriesList
            .do(onNext: { [weak self] _ in
                _ = self?.emptyView.subviews.map { $0.removeFromSuperview() }
                self?.emptyView.frame.size.height = 0
            })
            .drive { $0 }
            .map { [SectionModel(model: "series", items: $0)] }
            .bind(to: tableView.rx.items(dataSource: dataSource))
            .disposed(by: disposeBag)

        output
            .seriesList
            .drive(onNext: { [weak self] seriesList in
                let selectedSeriesId = self?.viewModel?.seriesId ?? 0
                guard let seriesIndex = seriesList.firstIndex(where: { $0.id == selectedSeriesId }) else { return }
                let indexPath = IndexPath(row: seriesIndex, section: 0)
                self?.tableView.selectRow(at: indexPath, animated: false, scrollPosition: .middle)
            })
            .disposed(by: disposeBag)

        output
            .selectedIndexPath
            .drive(onNext: { [weak self] indexPath in
                guard let delegate = self?.delegate else { return }
                let series = dataSource[indexPath]
                delegate.selectSeries(with: series)
            })
            .disposed(by: disposeBag)

        output
            .openUpdateSeriesPopup
            .drive(onNext: { [weak self] indexPath in
                guard let indexPath = indexPath else { return }
                let series = dataSource[indexPath]
                self?.openUpdateSeriesPopup(series: series)
            })
            .disposed(by: disposeBag)

        output
            .openDeleteConfirmPopup
            .drive(onNext: { [weak self] indexPath in
                guard let seriesId = dataSource[indexPath].id else { return }
                self?.openDeleteConfirmPopup(seriesId: seriesId)
            })
            .disposed(by: disposeBag)

        output
            .embedEmptyViewController
            .drive(onNext: { [weak self] style in
                guard let `self` = self else { return }
                self.embedCustomEmptyViewController(style: style)
            })
            .disposed(by: disposeBag)

        output
            .showToast
            .drive(onNext: { message in
                guard message != "" else { return }
                Toast.showToast(message)
            })
            .disposed(by: disposeBag)

        output
            .dismissViewController
            .drive(onNext: { [weak self] _ in
                self?.dismiss(animated: true)
            })
            .disposed(by: disposeBag)
    }
}

extension SeriesListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: LocalizedStrings.edit.localized(), handler: { [weak self] (action, view, completionHandler) in
            self?.contextualAction.onNext((action.style, indexPath))
            completionHandler(true)
        })

        let deleteAction = UIContextualAction(style: .destructive, title: LocalizedStrings.delete.localized(), handler: { [weak self] (action, view, completionHandler) in
            self?.contextualAction.onNext((action.style, indexPath))
            completionHandler(true)
        })

        return UISwipeActionsConfiguration(actions: [deleteAction, editAction])
    }

    func tableView(_ tableView: UITableView, willSelectRowAt indexPath: IndexPath) -> IndexPath? {
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow,
            indexPathForSelectedRow == indexPath {
            tableView.deselectRow(at: indexPath, animated: false)
            return nil
        }
        return indexPath
    }
}