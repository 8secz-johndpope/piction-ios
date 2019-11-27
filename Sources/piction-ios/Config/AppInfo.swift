//
//  AppInfo.swift
//  PictionView
//
//  Created by jhseo on 20/06/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit

let BUNDLEID = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""

let SCREEN_W = UIScreen.main.bounds.size.width
let SCREEN_H = UIScreen.main.bounds.size.height
let STATUS_HEIGHT: CGFloat = UIApplication.shared.statusBarFrame.size.height
let DEFAULT_NAVIGATION_HEIGHT: CGFloat = 44
var LARGE_NAVIGATION_HEIGHT: CGFloat {
    if #available(iOS 13, *) {
        return 104.33
    } else {
        return 96
    }
}

let FEATURE_EDITOR = false

final class AppInfo {
    static var isStaging: Bool {
        let infoDictionary: [AnyHashable: Any] = Bundle.main.infoDictionary!
        guard let appID: String = infoDictionary["CFBundleIdentifier"] as? String else { return false }
        return appID == "com.pictionnetwork.piction-test"
    }

    static var urlScheme: String {
        if isStaging {
            return "piction-test"
        } else {
            return "piction"
        }
    }
}
