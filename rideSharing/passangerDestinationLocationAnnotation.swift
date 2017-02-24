//
//  passangerDestinationLocationAnnotation.swift
//  ride-sharing
//
//  Created by Ian Thomas on 2/16/17.
//  Copyright © 2017 Geodex Systems. All rights reserved.
//

import UIKit
import MapKit

class passangerDestinationLocationAnnotation: NSObject, MKAnnotation {

    dynamic var coordinate: CLLocationCoordinate2D
   // var title: String?
    
    init(_ coordinate: CLLocationCoordinate2D, _ key: String) {
        self.coordinate = coordinate
    }
}
