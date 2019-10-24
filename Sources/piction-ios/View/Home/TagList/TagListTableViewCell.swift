//
//  TagListTableViewCell.swift
//  piction-ios
//
//  Created by jhseo on 17/10/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class TagListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var tagLabel: UILabel!
    @IBOutlet weak var projectCountLabel: UILabel!
    @IBOutlet weak var eventLabel: UILabel!

    typealias Model = TagModel

    func configure(with model: Model) {
        let (tagName, projectCount, label) = (model.name, model.taggingCount, model.label)
        tagLabel.text = "#\(tagName ?? "")"
        projectCountLabel.text = LocalizedStrings.str_project_count.localized(with: projectCount ?? 0)
        eventLabel.text = label
        eventLabel.isHidden = label == nil
    }
}
