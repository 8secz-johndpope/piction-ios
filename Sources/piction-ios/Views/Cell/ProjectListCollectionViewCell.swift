//
//  ProjectListCollectionViewCell.swift
//  piction-ios
//
//  Created by jhseo on 16/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class ProjectListCollectionViewCell: ReuseCollectionViewCell {
    @IBOutlet weak var thumbnailImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var nicknameLabel: UILabel!
    @IBOutlet weak var updateLabel: UILabel!

    override func prepareForReuse() {
        super.prepareForReuse()
        thumbnailImageView.sd_cancelCurrentImageLoad()
        thumbnailImageView.image = #imageLiteral(resourceName: "img-dummy-square-500-x-500")
    }

    typealias Model = ProjectModel

    func configure(with model: Model) {
        let (thumbnail, title, nickname, lastPublishedAt) = (model.thumbnail, model.title, model.user?.username, model.lastPublishedAt)

        if let thumbnail = thumbnail {
            let thumbnailWithIC = "\(thumbnail)?w=720&h=720&quality=80&output=webp"
            if let url = URL(string: thumbnailWithIC) {
                thumbnailImageView.sd_setImageWithFade(with: url, placeholderImage: #imageLiteral(resourceName: "img-dummy-square-500-x-500"), completed: nil)
            }
        }

        titleLabel.text = title
        nicknameLabel.text = nickname

        if let lastPublishedAt = lastPublishedAt {
            let diff = Calendar.current.dateComponents([.day], from: lastPublishedAt, to: Date())

            if let day = diff.day, day > 0 {
                updateLabel.isHidden = true
            } else {
                updateLabel.isHidden = false
            }
        } else {
            updateLabel.isHidden = true
        }
    }
}
