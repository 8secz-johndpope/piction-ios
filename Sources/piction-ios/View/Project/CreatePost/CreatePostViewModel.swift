//
//  CreatePostViewModel.swift
//  PictionView
//
//  Created by jhseo on 15/07/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import PictionSDK

final class CreatePostViewModel: InjectableViewModel {
    typealias Dependency = (
        UpdaterProtocol,
        String,
        Int
    )

    private let updater: UpdaterProtocol
    var uri: String = ""
    var postId: Int = 0

    private let title = PublishSubject<String>()
    private let content = PublishSubject<String>()
    private let coverImageId = PublishSubject<String?>()
    private let status = PublishSubject<String>()
    private let fanPassId = PublishSubject<Int?>()
    private let publishedAt = PublishSubject<Date?>()
    private let seriesId = PublishSubject<Int?>()

    init(dependency: Dependency) {
        (updater, uri, postId) = dependency
    }

    struct Input {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let selectSeriesBtnDidTap: Driver<Void>
        let seriesChanged: Driver<SeriesModel?>
        let fanPassChanged: Driver<FanPassModel?>
        let inputPostTitle: Driver<String>
        let inputContent: Driver<String>
        let contentImageDidPick: Driver<UIImage>
        let coverImageBtnDidTap: Driver<Void>
        let coverImageDidPick: Driver<UIImage>
        let deleteCoverImageBtnDidTap: Driver<Void>
        let forAllCheckBtnDidTap: Driver<Void>
        let forSubscriptionCheckBtnDidTap: Driver<Void>
        let forPrivateCheckBtnDidTap: Driver<Void>
        let selectFanPassBtnDidTap: Driver<Void>
        let publishNowCheckBtnDidTap: Driver<Void>
        let publishDatePickerBtnDidTap: Driver<Void>
        let publishDatePickerValueChanged: Driver<Date>
        let publishDateChanged: Driver<Date?>
        let saveBtnDidTap: Driver<Void>
    }

    struct Output {
        let viewWillAppear: Driver<Void>
        let viewWillDisappear: Driver<Void>
        let isModify: Driver<Bool>
        let openSeriesListViewController: Driver<(String, Int?)>
        let loadPostInfo: Driver<(PostModel, String)>
        let uploadContentImage: Driver<(String, UIImage)>
        let openCoverImagePicker: Driver<Void>
        let changeCoverImage: Driver<UIImage?>
        let statusChanged: Driver<String>
        let seriesChanged: Driver<SeriesModel?>
        let fanPassChanged: Driver<FanPassModel?>
        let openManageFanPassViewController: Driver<(String, Int?)>
        let publishNowChanged: Driver<Void>
        let openDatePicker: Driver<Date>
        let publishDatePickerValueChanged: Driver<Date>
        let publishDateChanged: Driver<Date?>
        let popViewController: Driver<Void>
        let activityIndicator: Driver<Bool>
        let dismissKeyboard: Driver<Bool>
        let showToast: Driver<String>
    }

    func build(input: Input) -> Output {
        let viewWillAppear = input.viewWillAppear.asObservable().take(1).asDriver(onErrorDriveWith: .empty())
            .flatMap { [weak self] _ -> Driver<Void> in
                self?.title.onNext("")
                self?.coverImageId.onNext("")
                self?.content.onNext("")
                self?.fanPassId.onNext(nil)
                self?.status.onNext("PUBLIC")
                self?.publishedAt.onNext(nil)
                self?.seriesId.onNext(nil)

                return Driver.just(())
            }

        let isModify = input.viewWillAppear
            .flatMap { [weak self] _ -> Driver<Bool> in
                guard let `self` = self else { return Driver.empty() }
                return Driver.just(self.postId != 0)
            }

        let loadPostAction = viewWillAppear
            .filter { self.postId != 0 }
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(PostsAPI.get(uri: self.uri, postId: self.postId))
                return Action.makeDriver(response)
            }

        let loadPostSuccess = loadPostAction.elements
            .flatMap { [weak self] response -> Driver<PostModel> in
                guard let post = try? response.map(to: PostModel.self) else {
                    return Driver.empty()
                }
                self?.title.onNext(post.title ?? "")
                self?.coverImageId.onNext("")
                self?.publishedAt.onNext(post.publishedAt ?? Date())
                self?.fanPassId.onNext(post.fanPass?.id)
                self?.status.onNext(post.status ?? "PUBLIC")
                self?.seriesId.onNext(post.series?.id)
                return Driver.just(post)
            }

        let loadContentAction = viewWillAppear
            .filter { self.postId != 0 }
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(PostsAPI.content(uri: self.uri, postId: self.postId))
                return Action.makeDriver(response)
            }

        let loadContentSuccess = loadContentAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard let contentItem = try? response.map(to: ContentModel.self) else {
                    return Driver.empty()
                }
                print("\(contentItem.content ?? "")")
                var content = (contentItem.content ?? "").replacingOccurrences(of: "</p> <p>", with: "</p><p>")
                content = content.convertTagIFrameToVideo()

                self?.content.onNext(content)
//                content = content.replacingOccurrences(of: "<div class=\"video\">  <iframe frameborder=\"0\" allowfullscreen=\"true\"", with: "<p><div class=\"video\">")
//                content = content.replacingOccurrences(of: "</iframe> </div>", with: "</div></p>")
//                content = content.replacingOccurrences(of: "<div class=\"video\">", with: "<p>")
//                content = content.replacingOccurrences(of: "</iframe> </div>", with: "</iframe></p>")
                print(content)
                return Driver.just(content)
            }

        let loadFanPassAction = viewWillAppear
            .flatMap { [weak self] _ -> Driver<Action<ResponseData>> in
                let response = PictionSDK.rx.requestAPI(ProjectsAPI.fanPassAll(uri: self?.uri ?? ""))
                return Action.makeDriver(response)
            }

        let loadFanPassSuccess = loadFanPassAction.elements
            .flatMap { response -> Driver<[FanPassModel]> in
                guard let fanPassList = try? response.map(to: [FanPassModel].self) else {
                    return Driver.empty()
                }
                return Driver.just(fanPassList)
            }

        let loadPostInfo = Driver.combineLatest(loadPostSuccess, loadContentSuccess)

        let postTitleChanged = Driver.merge(input.inputPostTitle, title.asDriver(onErrorDriveWith: .empty()))
            .flatMap { title -> Driver<String> in
                return Driver.just(title)
            }

        let postContentChanged = Driver.merge(input.inputContent, content.asDriver(onErrorDriveWith: .empty()))
            .flatMap { content -> Driver<String> in
                print(content)
                return Driver.just(content)
            }

        let uploadCoverImageAction = input.coverImageDidPick
            .flatMap { [weak self] image -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(PostsAPI.uploadCoverImage(uri: self.uri, image: image))
                return Action.makeDriver(response)
            }

        let uploadCoverImageError = uploadCoverImageAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let uploadCoverImageSuccess = uploadCoverImageAction.elements
            .flatMap { [weak self] response -> Driver<String> in
                guard let imageInfo = try? response.map(to: StorageAttachmentViewResponse.self) else {
                    return Driver.empty()
                }
                self?.coverImageId.onNext(imageInfo.id ?? "")
                return Driver.just(imageInfo.id ?? "")
            }

        let changeCoverImage = uploadCoverImageSuccess
            .withLatestFrom(input.coverImageDidPick)
            .flatMap { image -> Driver<UIImage?> in
                return Driver.just(image)
            }

        let deleteCoverImage = input.deleteCoverImageBtnDidTap
            .flatMap { [weak self] _ -> Driver<UIImage?> in
                self?.coverImageId.onNext(nil)
                return Driver.just(nil)
            }

        let coverImage = Driver.merge(changeCoverImage, deleteCoverImage)

        let uploadContentImageAction = input.contentImageDidPick
            .flatMap { [weak self] image -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                let response = PictionSDK.rx.requestAPI(PostsAPI.uploadContentImage(uri: self.uri, image: image))
                return Action.makeDriver(response)
            }

        let uploadContentImageSuccess = uploadContentImageAction.elements
            .flatMap { response -> Driver<String> in
                guard let imageInfo = try? response.map(to: StorageAttachmentViewResponse.self) else {
                    return Driver.empty()
                }
                return Driver.just(imageInfo.url ?? "")
            }

        let contentImage = Driver.zip(uploadContentImageSuccess, input.contentImageDidPick)
            .flatMap { (url, image) -> Driver<(String, UIImage)> in
                return Driver.just((url, image))
            }

        let uploadContentImageError = uploadContentImageAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let checkforAll = input.forAllCheckBtnDidTap
            .flatMap { [weak self] _ -> Driver<String> in
                self?.status.onNext("PUBLIC")
                self?.fanPassId.onNext(nil)
                return Driver.just("PUBLIC")
            }

        let checkforSubscription = input.forSubscriptionCheckBtnDidTap
            .withLatestFrom(loadFanPassSuccess)
            .flatMap { [weak self] fanPassInfo -> Driver<String> in
                self?.status.onNext("FAN_PASS")
                let fanPassId = fanPassInfo[safe: 0]?.id ?? nil
                self?.fanPassId.onNext(fanPassId)
                return Driver.just("FAN_PASS")
            }

        let checkforPrivate = input.forPrivateCheckBtnDidTap
            .flatMap { [weak self] _ -> Driver<String> in
                self?.status.onNext("PRIVATE")
                self?.fanPassId.onNext(nil)
                return Driver.just("PRIVATE")
            }

        let openManageFanPassViewController = input.selectFanPassBtnDidTap
            .withLatestFrom(fanPassId.asDriver(onErrorDriveWith: .empty()))
            .flatMap { [weak self] fanPassId -> Driver<(String, Int?)> in
                return Driver.just((self?.uri ?? "", fanPassId))
            }

        let publishNowChanged = input.publishNowCheckBtnDidTap

        let statusChanged = Driver.merge(checkforAll, checkforSubscription, checkforPrivate)

        let seriesChanged = input.seriesChanged
            .flatMap { [weak self] series -> Driver<SeriesModel?> in
                self?.seriesId.onNext(series?.id)
                return Driver.just(series)
            }

        let fanPassChanged = input.fanPassChanged
            .flatMap { [weak self] fanPass -> Driver<FanPassModel?> in
                self?.fanPassId.onNext(fanPass?.id)
                return Driver.just(fanPass)
            }

        let publishDateChanged = input.publishDateChanged
            .flatMap { [weak self] date -> Driver<Date?> in
                self?.publishedAt.onNext(date)
                return Driver.just(date)
            }

        let changePostInfo = Driver.combineLatest(postTitleChanged, postContentChanged, coverImageId.asDriver(onErrorDriveWith: .empty()), fanPassId.asDriver(onErrorDriveWith: .empty()), status.asDriver(onErrorDriveWith: .empty()), publishedAt.asDriver(onErrorDriveWith: .empty()), seriesId.asDriver(onErrorDriveWith: .empty())) { (title: $0, content: $1, coverImageId: $2, fanPassId: $3, status: $4, publishedAt: $5, seriesId: $6) }

        let saveButtonAction = input.saveBtnDidTap
            .withLatestFrom(changePostInfo)
            .flatMap { [weak self] changePostInfo -> Driver<Action<ResponseData>> in
                guard let `self` = self else { return Driver.empty() }
                var content = changePostInfo.content.replacingOccurrences(of: "strong>", with: "b>")
                content = content.replacingOccurrences(of: "em>", with: "i>")
                content = content.replacingOccurrences(of: "<i></i>", with: "<i><br></i>")
                content = content.replacingOccurrences(of: "<u></u>", with: "<u><br></u>")
                content = content.replacingOccurrences(of: "<b></b>", with: "<b><br></b>")
                content = content.replacingOccurrences(of: "<p> </p>", with: "<p><br></p>")
                content = content.replacingOccurrences(of: "<p></p>", with: "<p><br></p>")

                content = content.convertTagVideoToIFrame()
//                let youtubeIds = content.getYoutubeId()
//                for id in youtubeIds {
//                    content = content.replacingOccurrences(of: " poster=\"https://img.youtube.com/vi/\(id)/sddefault.jpg\"", with: "")
//                }
//
//                content = content.replacingOccurrences(of: "<p><video ", with: "<div class=\"video\">  <iframe frameborder=\"0\" allowfullscreen=\"true\"")
//                content = content.replacingOccurrences(of: "</video></p>", with: "</iframe> </div>")
                if self.postId == 0 {
                    let response = PictionSDK.rx.requestAPI(PostsAPI.create(uri: self.uri, title: changePostInfo.title, content: content, cover: changePostInfo.coverImageId, seriesId: changePostInfo.seriesId, fanPassId: changePostInfo.fanPassId, status: changePostInfo.status, publishedAt: changePostInfo.publishedAt?.millisecondsSince1970  ?? Date().millisecondsSince1970))
                    return Action.makeDriver(response)
                } else {
                    let response = PictionSDK.rx.requestAPI(PostsAPI.update(uri: self.uri, postId: self.postId, title: changePostInfo.title, content: content, cover: changePostInfo.coverImageId, seriesId: changePostInfo.seriesId, fanPassId: changePostInfo.fanPassId, status: changePostInfo.status, publishedAt: changePostInfo.publishedAt?.millisecondsSince1970 ?? Date().millisecondsSince1970))
                    return Action.makeDriver(response)
                }
            }

        let changePostInfoSuccess = saveButtonAction.elements
            .flatMap { [weak self] response -> Driver<Void> in
                guard let project = try? response.map(to: ProjectModel.self) else {
                    return Driver.empty()
                }
                print(project)
                self?.updater.refreshContent.onNext(())
                return Driver.just(())
            }

        let changePostInfoError = saveButtonAction.error
            .flatMap { response -> Driver<String> in
                let errorMsg = response as? ErrorType
                return Driver.just(errorMsg?.message ?? "")
            }

        let openDatePicker = input.publishDatePickerBtnDidTap
            .withLatestFrom(publishedAt.asDriver(onErrorDriveWith: .empty()))
            .flatMap { publishedAt -> Driver<Date> in
                if let publishedAt = publishedAt {
                    return Driver.just(publishedAt)
                } else {
                    return Driver.just(Date())
                }
            }

        let openSeriesListViewController = input.selectSeriesBtnDidTap
            .withLatestFrom(seriesId.asDriver(onErrorDriveWith: .empty()))
            .flatMap { [weak self] seriesId -> Driver<(String, Int?)> in
                return Driver.just((self?.uri ?? "", seriesId))
            }

        let activityIndicator = Driver.merge(
            uploadCoverImageAction.isExecuting,
            uploadContentImageAction.isExecuting,
            saveButtonAction.isExecuting)

        let showToast = Driver.merge(uploadCoverImageError, uploadContentImageError, changePostInfoError)

        let dismissKeyboard = saveButtonAction.isExecuting

        return Output(
            viewWillAppear: input.viewWillAppear,
            viewWillDisappear: input.viewWillDisappear,
            isModify: isModify,
            openSeriesListViewController: openSeriesListViewController,
            loadPostInfo: loadPostInfo,
            uploadContentImage: contentImage,
            openCoverImagePicker: input.coverImageBtnDidTap,
            changeCoverImage: coverImage,
            statusChanged: statusChanged,
            seriesChanged: seriesChanged,
            fanPassChanged: fanPassChanged,
            openManageFanPassViewController: openManageFanPassViewController,
            publishNowChanged: publishNowChanged,
            openDatePicker: openDatePicker,
            publishDatePickerValueChanged: input.publishDatePickerValueChanged,
            publishDateChanged: publishDateChanged,
            popViewController: changePostInfoSuccess,
            activityIndicator: activityIndicator,
            dismissKeyboard: dismissKeyboard,
            showToast: showToast
        )
    }
}
