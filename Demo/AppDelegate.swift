// Copyright 2016–2017 Stephan Tolksdorf

import UIKit

#if !swift(>=4.2)
  extension UIApplication {
    typealias LaunchOptionsKey = UIApplicationLaunchOptionsKey
  }
#endif

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

  var window: UIWindow?


  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?)
    -> Bool
  {

    let window = UIWindow()

    self.window = window
    window.backgroundColor = .white

    let navigationVC = UINavigationController(rootViewController: RootViewController())

    window.rootViewController = navigationVC

    window.makeKeyAndVisible()

    return true
  }
}


