//
//  CreateProjectViewModel.swift
//  PictionView
//
//  Created by jhseo on 15/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

final class CreateProjectViewModel: InjectableViewModel {
    typealias Dependency = (
        UpdaterProtocol,
        String
    )

    private let updater: UpdaterProtocol
    var uri: String = ""

    private let title = PublishSubject<String>()
    private let id = PublishSubject<String>()
    private let synopsis = PublishSubject<String>()
    private let wideThumbnailImageId = PublishSubject<String?>()
    private let thumbnailImageId = PublishSubject<String?>()
    private let status = PublishSubject<String>()
    private let tags = PublishSubject<[String]>()

    init(dependency: Dependency) {
        (updater, uri) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let inputProjectTitle: Driver<String>
        let inputProjectId: Driver<String>
        let wideThumbnailBtnDidTap: Driver<Void>
        let thumbnailBtnDidTap: Driver<Void>
        let wideThumbnailImageDidPick: Driver<UIImage>
        let thumbnailImageDidPick: Driver<UIImage>
        let deleteWideThumbnailBtnDidTap: Driver<Void>
        let deleteThumbnailBtnDidTap: Driver<Void>
        let inputTags: Driver<[String]>
        let privateProjectCheckBoxBtnDidTap: Driver<Void>
        let inputSynopsis: Driver<String>
        let saveBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let isModify: Driver<Bool>
        let loadProject: Driver<ProjectModel>
        let projectIdChanged: Driver<String>
        let openWideThumbnailImagePicker: Driver<Void>
        let openThumbnailImagePicker: Driver<Void>
        let changeWideThumbnail: Driver<UIImage?>
        let changeThumbnail: Driver<UIImage?>
        let statusChanged: Driver<String>
        let popViewController: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissKeyboard: Driver<Bool>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let (updater, uri) = (self.updater, self.uri)

        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())

        let isModify = viewWillAppear
            .flatMap { _ in Driver.just(uri != "") }

        let loadProjectAction = viewWillAppear
            .do(onNext: { [weak self] in
                guard let `self` = self else { return }
                self.thumbnailImageId.onNext(nil)
                self.wideThumbnailImageId.onNext(nil)
                self.synopsis.onNext("")
                self.status.onNext("PUBLIC")
                self.tags.onNext([])
            })
            .filter { uri != "" }
            .flatMap { _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.get(uri: uri))
                return Action.makeDriver(response)
            }

        let loadProjectSuccess = loadProjectAction.elements
            .flatMap { [weak self] response -> Driver<ProjectModel> in
                guard
                    let `self` = self,
                    let project = try? response.map(to: ProjectModel.self),
                    let title = project.title,
                    let uri = project.uri,
                    let synopsis = project.synopsis,
                    let status = project.status
                else { return Driver.empty() }

                self.title.onNext(title)
                self.id.onNext(uri)
                self.thumbnailImageId.onNext("")
                self.wideThumbnailImageId.onNext("")
                self.synopsis.onNext(synopsis)
                self.status.onNext(status)
                self.tags.onNext([])

                return Driver.just(project)
            }

        let projectTitleChanged = Driver.merge(input.inputProjectTitle, title.asDriver(onErrorDriveWith: .empty()))
            .flatMap { title in Driver<String>.just(title) }

        let projectIdChanged = Driver.merge(input.inputProjectId, id.asDriver(onErrorDriveWith: .empty()))
            .flatMap { id in Driver<String>.just(id) }

        let synopsisChanged = Driver.merge(input.inputSynopsis, synopsis.asDriver(onErrorDriveWith: .empty()))
            .flatMap { synopsis in Driver<String>.just(synopsis) }

        let uploadWideThumbnailImageAction = input.wideThumbnailImageDidPick
            .flatMap { image -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.uploadWideThumbnail(image: image))
                return Action.makeDriver(response)
            }

        let uploadWideThumbnailError = uploadWideThumbnailImageAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else { return Driver.empty() }
                return Driver.just(errorMsg.message)
            }

        let uploadWideThumbnailSuccess = uploadWideThumbnailImageAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard
                    let `self` = self,
                    let imageInfo = try? response.map(to: StorageAttachmentViewResponse.self),
                    let imageInfoId = imageInfo.id
                else { return Driver.empty() }

                self.wideThumbnailImageId.onNext(imageInfoId)
                return Driver.just(imageInfoId)
            }

        let changeWideThumbnail = uploadWideThumbnailSuccess
            .withLatestFrom(input.wideThumbnailImageDidPick)
            .flatMap { image in Driver<UIImage?>.just(image) }

        let deleteWideThumbnail = input.deleteWideThumbnailBtnDidTap
            .flatMap { [weak self] _ -> Driver<UIImage?> in
                self?.wideThumbnailImageId.onNext(nil)
                return Driver.just(nil)
            }

        let wideThumbnailImage = Driver.merge(changeWideThumbnail, deleteWideThumbnail)

        let uploadThumbnailImageAction = input.thumbnailImageDidPick
            .flatMap { image -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.uploadThumbnail(image: image))
                return Action.makeDriver(response)
            }

        let uploadThumbnailError = uploadThumbnailImageAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else { return Driver.empty() }
                return Driver.just(errorMsg.message)
            }

        let uploadThumbnailSuccess = uploadThumbnailImageAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard
                    let `self` = self,
                    let imageInfo = try? response.map(to: StorageAttachmentViewResponse.self),
                    let imageInfoId = imageInfo.id
                else { return Driver.empty() }

                self.thumbnailImageId.onNext(imageInfoId)
                return Driver.just(imageInfoId)
            }

        let changeThumbnail = uploadThumbnailSuccess
            .withLatestFrom(input.thumbnailImageDidPick)
            .flatMap { image in Driver<UIImage?>.just(image) }

        let deleteThumbnail = input.deleteThumbnailBtnDidTap
            .flatMap { [weak self] _ -> Driver<UIImage?> in
                self?.thumbnailImageId.onNext(nil)
                return Driver.just(nil)
            }

        let statusChanged = input.privateProjectCheckBoxBtnDidTap
            .withLatestFrom(status.asDriver(onErrorDriveWith: .empty()))
            .flatMap { [weak self] status -> Driver<String> in
                if status == "PUBLIC" {
                    self?.status.onNext("HIDDEN")
                    return Driver.just("HIDDEN")
                } else {
                    self?.status.onNext("PUBLIC")
                    return Driver.just("PUBLIC")
                }
            }

        let tagsChanged = Driver.merge(input.inputTags, tags.asDriver(onErrorDriveWith: .empty()))
            .flatMap { tags -> Driver<[String]> in
                return Driver.just(tags)
            }

        let thumbnailImage = Driver.merge(changeThumbnail, deleteThumbnail)

        let changeProjectInfo = Driver.combineLatest(projectTitleChanged, projectIdChanged, wideThumbnailImageId.asDriver(onErrorJustReturn: nil), thumbnailImageId.asDriver(onErrorJustReturn: nil), synopsisChanged, status.asDriver(onErrorDriveWith: .empty()), tagsChanged) { (title: $0, id: $1, wideThumbnailImageId: $2, thumbnailImageId: $3, synopsis: $4, status: $5, tags: $6) }

        let saveButtonAction = input.saveBtnDidTap
            .withLatestFrom(changeProjectInfo)
            .flatMap { changeProjectInfo -> Driver<Action<ResponseData>> in
                if uri == "" {
                    let response = PictionSDK.rx.requestAPI(ProjectsAPI.create(uri: changeProjectInfo.id, title: changeProjectInfo.title, synopsis: changeProjectInfo.synopsis, thumbnail: changeProjectInfo.thumbnailImageId, wideThumbnail: changeProjectInfo.wideThumbnailImageId, tags: changeProjectInfo.tags, status: changeProjectInfo.status))
                    return Action.makeDriver(response)
                } else {
                    let response = PictionSDK.rx.requestAPI(ProjectsAPI.update(uri: changeProjectInfo.id, title: changeProjectInfo.title, synopsis: changeProjectInfo.synopsis, thumbnail: changeProjectInfo.thumbnailImageId, wideThumbnail: changeProjectInfo.wideThumbnailImageId, tags: changeProjectInfo.tags, status: changeProjectInfo.status))
                    return Action.makeDriver(response)
                }
            }

        let changeProjectInfoSuccess = saveButtonAction.elements
            .flatMap { _ -> Driver<Void> in
                updater.refreshContent.onNext(())
                return Driver.just(())
            }

        let changeProjectInfoError = saveButtonAction.error
            .flatMap { response -> Driver<String> in
                guard let errorMsg = response as? ErrorType else { return Driver.empty() }
                return Driver.just(errorMsg.message)
            }

        let activityIndicator = Driver.merge(
            uploadWideThumbnailImageAction.isExecuting,
            uploadThumbnailImageAction.isExecuting,
            saveButtonAction.isExecuting)

        let showToast = Driver.merge(uploadWideThumbnailError, uploadThumbnailError, changeProjectInfoError)

        let dismissKeyboard = saveButtonAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            isModify: isModify,
            loadProject: loadProjectSuccess,
            projectIdChanged: projectIdChanged,
            openWideThumbnailImagePicker: input.wideThumbnailBtnDidTap,
            openThumbnailImagePicker: input.thumbnailBtnDidTap,
            changeWideThumbnail: wideThumbnailImage,
            changeThumbnail: thumbnailImage,
            statusChanged: statusChanged,
            popViewController: changeProjectInfoSuccess,
            activityIndicator: activityIndicator,
            dismissKeyboard: dismissKeyboard,
            showToast: showToast
        )
    }
}
