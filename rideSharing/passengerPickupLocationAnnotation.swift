//
//  userLocationAnnotation.swift
//  ride-sharing
//
//  Created by Ian Thomas on 2/15/17.
//  Copyright © 2017 Geodex Systems. All rights reserved.
//

import UIKit
import MapKit

class passengerPickupLocationAnnotation: NSObject, MKAnnotation {
    
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String?
    
    init(_ coordinate: CLLocationCoordinate2D, _ title: String) {
        self.coordinate = coordinate
        self.title = title
    }
}
