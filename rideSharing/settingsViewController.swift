//
//  settingsViewController.swift
//  ride-sharing
//
//  Created by Ian Thomas on 2/13/17.
//  Copyright © 2017 Geodex Systems. All rights reserved.
//

import UIKit


class settingsViewController: UIViewController {
    
    @IBOutlet weak var appVersionLabel: UILabel!
    @IBOutlet weak var onOffDutySegmentedControl: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    
        let startingSegmentPossition = UserDefaults.standard.object(forKey: kUserStatusMode) as! Int
        onOffDutySegmentedControl.selectedSegmentIndex = startingSegmentPossition
        
        onOffDutySegmentedControl.addTarget(self, action: #selector(settingsViewController.updateSwitch(_:)), for: .valueChanged)
        
        
        let infoDictionary = Bundle.main.infoDictionary
        
        if let appVersion = infoDictionary?["CFBundleShortVersionString"] as? String,
            let buildNumber = infoDictionary?["CFBuildNumber"] as? String,
            let buildDate = infoDictionary?["CFBuildDate"] as? String {
            
            appVersionLabel.text = "App Version: \(appVersion)\n Build Number: \(buildNumber)\n Build Date: \(buildDate)"
        }
    }
    
    func updateSwitch (_ segmentedControl: UISegmentedControl) {
    
        NotificationCenter.default.post(name: Notification.Name("changedUserStatus"), object: segmentedControl.selectedSegmentIndex)
    }
    
    @IBAction func close () {
        self.dismiss(animated: true, completion: nil)
    }
}
