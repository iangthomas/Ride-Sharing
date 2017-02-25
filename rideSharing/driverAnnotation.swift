//
//  driverAnnotation.swift
//  ride-sharing
//
//  Created by Ian Thomas on 2/14/17.
//  Copyright © 2017 Geodex Systems. All rights reserved.
//

import UIKit
import MapKit

class driverAnnotation: NSObject, MKAnnotation {
    
    dynamic var coordinate: CLLocationCoordinate2D
    var key: String
    
    init(_ coordinate: CLLocationCoordinate2D, _ key: String) {
        self.coordinate = coordinate
        self.key = key
    }
}
