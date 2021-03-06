//
//  SeriesPostListTableViewCell.swift
//  PictionView
//
//  Created by jhseo on 02/09/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import PictionSDK

final class SeriesPostListTableViewCell: ReuseTableViewCell {
    @IBOutlet weak var numberLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subTitleLabel: UILabel!

    typealias Model = PostModel

    override func layoutSubviews() {
        self.contentView.autoresizingMask = [.flexibleHeight]

        super.layoutSubviews()
    }

    func configure(with model: Model, isSubscribing: Bool, number: Int) {
        let (title, date, fanPass) = (model.title, model.createdAt, model.fanPass)

        numberLabel.text = "#\(number)"

        titleLabel.text = title

        if isSubscribing || fanPass == nil {
            subTitleLabel.textColor = .pictionGray
            subTitleLabel.text = date?.toString(format: LocalizedStrings.str_series_date_format.localized())
        } else {
            subTitleLabel.textColor = .pictionRed
            if fanPass != nil {
                subTitleLabel.text = (fanPass?.level ?? 0) == 0 ? LocalizedStrings.str_series_subs_only.localized() :  LocalizedStrings.str_series_fanpass_subs_only.localized(with: fanPass?.name ?? "")
            }
        }
    }
}
