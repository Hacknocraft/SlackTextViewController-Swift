//
//  AppDelegate.swift
//  Programatic Example
//
//  Created by Lebron on 22/08/2017.
//  Copyright © 2017 Lebron. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .white
        window?.rootViewController = UINavigationController(rootViewController: MessageViewController())
        window?.makeKeyAndVisible()

        return true
    }

}
