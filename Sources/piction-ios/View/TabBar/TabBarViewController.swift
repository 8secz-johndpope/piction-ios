//
//  TabBarViewController.swift
//  PictionSDK
//
//  Created by jhseo on 02/08/2019.
//  Copyright © 2019 Piction Network. All rights reserved.
//

import UIKit
import RxSwift
import Swinject

final class TabBarController: UITabBarController {

    var previousViewController: UIViewController?
    private var lastIndex = 0 {
        didSet {
            lastIndexExceptLibrary = lastIndex != 2 ? lastIndex : lastIndexExceptLibrary
        }
    }
    private var lastIndexExceptLibrary = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setTabBar(with: TabBarItem.all)
        self.delegate = self

        UITabBar.appearance().tintColor = .pictionBlue
    }

    private func setTabBar(with types: [TabBarItem]) {
        viewControllers = types.map { item -> UINavigationController in
            let viewController = item.makeViewController()
            let navigationController = UINavigationController(rootViewController: viewController)
            navigationController.navigationBar.prefersLargeTitles = true

            return navigationController
        }
    }

    func moveToSelectTab(_ type: TabBarItem, toRoot: Bool = false) {
        selectedIndex = type.rawValue

        if toRoot {
            self.tabBar.isHidden = false
            if let vc = viewControllers?[type.rawValue] as? UINavigationController {
                vc.popToRootViewController(animated: true)
                tabBarController(self, didSelect: vc)
            }
        }
    }
}
extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, shouldSelect viewController: UIViewController) -> Bool {
        self.previousViewController = tabBarController.selectedViewController?.children.last

        guard let toIndex = tabBarController.viewControllers?.firstIndex(of: viewController) else {
            return false
        }

        animateToTab(toIndex)
        return true
    }

    func animateToTab(_ toIndex: Int) {
        guard let tabViewControllers = self.viewControllers else { return }
        guard let fromIndex = tabViewControllers.firstIndex(of: selectedViewController!) else { return }
        guard let fromView = tabViewControllers[fromIndex].view else { return }
        guard let toView = tabViewControllers[toIndex].view else { return }
        if fromIndex == toIndex { return }

        // Add the toView to the tab bar view
        fromView.superview?.addSubview(toView)

        // Position toView off screen (to the left/right of fromView)
        let scrollRight = toIndex > fromIndex
        let offset = (scrollRight ? SCREEN_W : -SCREEN_W)
        toView.center = CGPoint(x: fromView.center.x + offset, y: toView.center.y)

        // Disable interaction during animation
        view.isUserInteractionEnabled = false

        UIView.animate(withDuration: 0.3, delay: 0.0, usingSpringWithDamping: 1, initialSpringVelocity: 0.7, options: .curveEaseInOut, animations: {
            // Slide the views by -offset
            fromView.center = CGPoint(x: fromView.center.x - offset, y: fromView.center.y)
            toView.center   = CGPoint(x: toView.center.x - offset, y: toView.center.y)
        }, completion: { _ in
            // Remove the old view from the tabbar view.
            fromView.removeFromSuperview()
            self.selectedIndex = toIndex
            self.view.isUserInteractionEnabled = true
        })
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let topViewController = UIApplication.topViewController() else { return }
        lastIndex = selectedIndex
        if let lastViewController = tabBarController.selectedViewController?.children.last,
            lastViewController is HomeViewController {
            if lastViewController.navigationItem.searchController?.isActive ?? false {
                lastViewController.navigationItem.searchController?.searchBar.text = nil
                lastViewController.navigationItem.searchController?.dismiss(animated: true)
            }
        }

        if previousViewController == tabBarController.selectedViewController?.children.last {
            guard viewController.children.count == 1 else { return }
            guard topViewController.navigationController?.navigationBar.frame.size.height == DEFAULT_NAVIGATION_HEIGHT else { return }
            switch topViewController {
            case is HomeViewController:
                guard let vc = topViewController as? HomeViewController else { return }
                guard let searchControllerIsActive = topViewController.navigationItem.searchController?.isActive else { return }
                if searchControllerIsActive {
                    vc.navigationItem.searchController?.searchBar.text = nil
                    vc.navigationItem.searchController?.dismiss(animated: true)
                } else if vc.navigationController?.navigationBar.frame.size.height == DEFAULT_NAVIGATION_HEIGHT {
                    vc.scrollView.setContentOffset(CGPoint(x: 0, y: -vc.statusHeight-vc.largeTitleNavigationHeight), animated: true)
                }
            case is ExploreViewController:
                guard let vc = topViewController as? ExploreViewController else { return }
                setOffset(scrollView: vc.collectionView, vc: vc)
            case is SubscriptionListViewController:
                guard let vc = topViewController as? SubscriptionListViewController else { return }
                setOffset(scrollView: vc.collectionView, vc: vc)
            case is MyPageViewController:
                guard let vc = topViewController as? MyPageViewController else { return }
                setOffset(scrollView: vc.tableView, vc: vc)
            default:
                break
            }
        }
    }

    private func setOffset(scrollView: UIScrollView, vc: UIViewController) {
        if #available(iOS 13, *) {
            if scrollView.contentSize.height < vc.visibleHeight {
                scrollView.setContentOffset(CGPoint(x: 0, y: -vc.statusHeight-DEFAULT_NAVIGATION_HEIGHT), animated: true)
            } else {
                scrollView.setContentOffset(CGPoint(x: 0, y: -vc.statusHeight-vc.largeTitleNavigationHeight), animated: true)
            }
        } else {
            if scrollView.contentSize.height < vc.visibleHeight {
                scrollView.setContentOffset(CGPoint(x: 0, y: -vc.statusHeight-DEFAULT_NAVIGATION_HEIGHT-16), animated: true)
            } else {
                return scrollView.setContentOffset(CGPoint(x: 0, y: -vc.statusHeight-vc.largeTitleNavigationHeight), animated: true)
            }
        }
    }
}

enum TabBarItem: Int {
    case home
    case explore
    case subscription
    case myPage

    static var all: [TabBarItem] {
        return [.home, .explore, .subscription, .myPage]
    }
}

extension TabBarItem {
    private func makeTabBarItem() -> UITabBarItem {
        let items: (String, UIImage?, UIImage?)

        switch self {
        case .home:
            items = (
                LocalizedStrings.tab_home.localized(),
                #imageLiteral(resourceName: "icTab1Unselected"),
                #imageLiteral(resourceName: "icTab1Active")
            )
        case .explore:
            items = (
                LocalizedStrings.tab_explore.localized(),
                #imageLiteral(resourceName: "icTab2Unselected"),
                #imageLiteral(resourceName: "icTab2Active")
            )
        case .subscription:
            items = (
                LocalizedStrings.tab_subscription.localized(),
                #imageLiteral(resourceName: "icTab3Unselected"),
                #imageLiteral(resourceName: "icTab3Active")
            )
        case .myPage:
            items = (
                LocalizedStrings.menu_my_info.localized(),
                #imageLiteral(resourceName: "icTab5Unselected"),
                #imageLiteral(resourceName: "icTab5Active")
            )
        }

        let tabBarItem = UITabBarItem(
            title: items.0,
            image: items.1,
            selectedImage: items.2
        )

        return tabBarItem
    }

    fileprivate func makeViewController() -> UIViewController {
        let viewController: UIViewController

        switch self {
        case .home:
            viewController = HomeViewController.make()
        case .explore:
            viewController = ExploreViewController.make()
        case .subscription:
            viewController = SubscriptionListViewController.make()
        case .myPage:
            viewController = MyPageViewController.make()
        }

        viewController.tabBarItem = makeTabBarItem()
        return viewController
    }
}
