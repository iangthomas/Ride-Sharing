//
//  AppDelegate.swift
//  ride-sharing
//
//  Created by Ian Thomas on 2/13/17.
//  Copyright © 2017 Geodex Systems. All rights reserved.
//

import UIKit
import CoreLocation
import MapKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var window: UIWindow?
    
    var ref: FIRDatabaseReference!
    
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        FIRApp.configure()
        ref = FIRDatabase.database().reference()
 
        
        if userProfileReady() == false {
            createInitialUserProfile()
        }
        
        return true
    }
    
    
    func userProfileReady() -> Bool {
        if let _ = UserDefaults.standard.string(forKey: kAppUserID) as String? {
            return true
        } else {
            return false
        }
    }

    
    func createInitialUserProfile () {
        
        let postDictionary = [
            "stars" : "0",
            "userType" : "Anonymous"
            ] as [String : Any]
        
        ref.child("users").childByAutoId().setValue(postDictionary, withCompletionBlock: { (error, requestReference) in
            
            if error == nil {
                
                let defaults = UserDefaults.standard
                let dictionary = [
                    kauto_anonymous_stats: true,
                    kauto_crash_reporting: true,
                    kAppUserID : "",
                    kUserStatusMode : 0
                    ] as [String : Any]
                
                defaults.register(defaults: dictionary)
                
                defaults.set(requestReference.key, forKey: kAppUserID)
                defaults.synchronize()
                
                NotificationCenter.default.post(name: NSNotification.Name("userProfileCreated"), object: nil)
            } else {
            // try again
                self.createInitialUserProfile ()
            }
        })
    }
    
    // todo impliment this at a later date
    func showTutorial () {
        
        let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
        _ = storyboard.instantiateViewController(withIdentifier: "tutorialNav")
     
        let initialViewController: UINavigationController = storyboard.instantiateViewController(withIdentifier: "tutorialNav") as! UINavigationController
        
        self.window = UIWindow(frame: UIScreen.main.bounds)
        self.window?.rootViewController = initialViewController
        self.window?.makeKeyAndVisible()
    }
    
    
    func applicationWillResignActive(_ application: UIApplication) {
        
        NotificationCenter.default.post(name: NSNotification.Name("closingApp"), object: nil)
        
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }
    
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    
}

