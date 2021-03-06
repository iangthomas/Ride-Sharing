//
//  passengerDestinationLocationAnnotation.swift
//  ride-sharing
//
//  Created by Ian Thomas on 2/16/17.
//  Copyright © 2017 Geodex Systems. All rights reserved.
//

import UIKit
import MapKit

class passengerDestinationLocationAnnotation: NSObject, MKAnnotation {

    dynamic var coordinate: CLLocationCoordinate2D
    
    init(_ coordinate: CLLocationCoordinate2D, _ key: String) {
        self.coordinate = coordinate
    }
}
