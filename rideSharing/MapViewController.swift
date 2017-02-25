//
//  MapViewController.swift
//  ride-sharing
//
//  Created by Ian Thomas on 2/13/17.
//  Copyright © 2017 Geodex Systems. All rights reserved.
//

import UIKit
import MapKit
import Firebase
import CoreLocation
import GeoFire

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    // Driver and Passenger IBOutlets
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var blankButton: UIButton!
    
    // Passenger IBOutlets
    @IBOutlet weak var centerButton: UIButton!
    
    // Driver IBOutlets
    // (UI in the pickup request screen)
    @IBOutlet weak var pickupRequestView: UIView!
    @IBOutlet weak var acceptPassenger: UIButton!
    @IBOutlet weak var passPassenger: UIButton!
    @IBOutlet weak var passengerName: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var onTripButton: UIButton!
    @IBOutlet weak var completeTripButton: UIButton!
    @IBOutlet weak var countdownLabel: UILabel!
    

    // Driver and Passenger Variables
    var thisAppUserID: String!
    var userStatusMode: Int!
    
    let locationManager = CLLocationManager()
    var currentLocation: CLLocation!
    var zoomedToInitialLocation = false
    
    var ref: FIRDatabaseReference!
    var geoCoder: CLGeocoder!
    
    var activeRequestPath: FIRDatabaseReference!
    var activeDriverUserRequestPath: FIRDatabaseReference!
    var watchingThisUsersDirectoryForPickupRequests: FIRDatabaseHandle!
    var watchingMainRequestDirectoryForPickupRequests: FIRDatabaseHandle!
    
    // Driver variables
    var isEnroute: Bool!
    var requestDirectoryRequestID: String!
    var pickupRequestUserUniqueID: String!
    var theTripDirectory: String!
    
    // Passenger variables
    var nearbyDrivers: [String: Any] = [:]
    var driversThatPassed: [String: String] =  [:]
    var noResponseTimer: Timer!
    var watchDriverForPickup: FIRDatabaseHandle!
    var lookingForDriversInRegionQuery: GFRegionQuery!
    var pickupLocation: [String: CLLocationDegrees] = [:]
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: Setup and UI
    // driver and passenger method
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = FIRDatabase.database().reference()
        
        setupGUI()
        
        if isUserProfileReady() {
            setupMapViewController()
            
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(MapViewController.userProfileCreated), name: NSNotification.Name("userProfileCreated"), object: nil)
        }
    }
    
    // driver and passenger method
    func isUserProfileReady() -> Bool {
        if let _ = UserDefaults.standard.string(forKey: kAppUserID) as String? {
            return true
        } else {
            return false
        }
    }
    
    // driver and passenger method
    func setupMapViewController () {
        NotificationCenter.default.addObserver(self, selector: #selector(MapViewController.ifLookingForPassengerThenStop), name: NSNotification.Name("closingApp"), object: nil)
        setupUserTypeSwitching()
        setupLocationManager()
    }
    
    // driver and passenger method
    func userProfileCreated () {
        setupMapViewController()
    }
    
    // driver and passenger method
    @IBAction func settingsButtonTapped (_ sender: Any) {
        self.performSegue(withIdentifier: "settings", sender: nil)
    }
    
    // driver and passenger method
    func setupUserTypeSwitching () {
        
        NotificationCenter.default.addObserver(self, selector: #selector(MapViewController.updateStatus), name: NSNotification.Name("changedUserStatus"), object: nil)
        
        userStatusMode = UserDefaults.standard.integer(forKey: kUserStatusMode)
        thisAppUserID = UserDefaults.standard.string(forKey: kAppUserID)
        
        
        NotificationCenter.default.post(name: NSNotification.Name("changedUserStatus"), object: userStatusMode)
    }
    
    // driver and passenger method
    func updateStatus (_ theNotification: NSNotification) {
        
        let userStatus = theNotification.object as! Int
        userStatusMode = userStatus
        
        let defaults = UserDefaults.standard
        defaults.set(userStatus, forKey: kUserStatusMode)
        defaults.synchronize()
        
        
        if userStatus == Int(KmodePassanger) {
            // passenger
            requestButton.isEnabled = true
            requestButton.setTitle("Request Pickup", for: .normal)
            centerButton.isHidden = false
            addressLabel.text = "Loading Address"
            
            stopLookingForPassengers()
            
        } else {
            // driver
            requestButton.setTitle("Looking For Passengers", for: .normal)
            centerButton.isHidden = true
            requestButton.isEnabled = false
            addressLabel.text = ""
            
            // did the user request a ride before switching? If so cancel the ride.
            if activeRequestPath != nil {
                cancelRide()
            }
            
            startLookingForPassengers()
            updateDriverLocationInDatabase()
        }
    }
    
    // driver and passenger method
    func setupLocationManager () {
        
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        }
        
        locationManager.delegate = self
        locationManager.distanceFilter = 5
        locationManager.startUpdatingLocation()
    }
    
    // driver and passenger method
    func setupGUI () {
        self.view.sendSubview(toBack: onTripButton)
        self.view.sendSubview(toBack: cancelButton)
        self.view.sendSubview(toBack: pickupRequestView)
        self.view.sendSubview(toBack: completeTripButton)
        self.view.sendSubview(toBack: blankButton)
    }
    
    // driver and passenger method
    func removeAllDriverAnnotations () {
        for annotation in mapView.annotations {
            if annotation is driverAnnotation {
                mapView.removeAnnotation(annotation)
            }
        }
    }
    
    // passenger method
    func isDriverBeingDisplayed (_ keyString: String) -> Bool {
        for annotation in mapView.annotations {
            
            if let aDriver = annotation as? driverAnnotation {
                if aDriver.key == keyString {
                    return true
                }
            }
        }
        return false
    }
    
    // passenger method
    func moveDriverAnnotation(_ theKey: String, _ newLocation: CLLocationCoordinate2D) {
        
        for annot in self.mapView.annotations {
            if annot is driverAnnotation {
                let new = annot as! driverAnnotation
                
                if new.key == theKey {
                    new.coordinate = newLocation
                }
            }
        }
    }
    
    // passenger method
    func stopLookingForDrivers () {
        
        // stop any active geofire queries looking for drivers
        if lookingForDriversInRegionQuery != nil {
            lookingForDriversInRegionQuery.removeAllObservers()
        }
        removeAllDriverAnnotations()
    }
    
    // passenger method
    func showDriverOnMapEnrouteToPassenger (_ driverID: String, _ passengerPickupLocationDictionary: NSDictionary) {
        
        let passengerPickupLocationCoor = CLLocationCoordinate2D(latitude: passengerPickupLocationDictionary.object(forKey: kLatitude) as! CLLocationDegrees, longitude: passengerPickupLocationDictionary.object(forKey: kLongitude) as! CLLocationDegrees)
        
        watchDriverForPickup = ref.child("enrouteDrivers").child(driverID).observe(.value, with: { (locationSnapshot) in
            
            if let locationDictionary = locationSnapshot.value as? NSDictionary {
                
                if let locationArray = locationDictionary.object(forKey: "l") as? NSArray {
                    
                    let driverLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: locationArray[0] as! CLLocationDegrees, longitude: locationArray[1] as! CLLocationDegrees)
                    
                    if self.isDriverBeingDisplayed(driverID) {
                        
                        self.moveDriverAnnotation(driverID, driverLocation)
                        
                        self.displayDriverDrivingDirections(from: driverLocation, to: passengerPickupLocationCoor)
                        
                    } else { // add their annotation
                        
                        let newDriverAnnotation:driverAnnotation = driverAnnotation.init(driverLocation, driverID)
                        
                        self.mapView.addAnnotation(newDriverAnnotation)
                        self.displayDriverDrivingDirections(from: driverLocation, to: passengerPickupLocationCoor)
                    }
                }
            }
        })
    }
    
    // passanger method
    //
    // did region change, if so, then update the search criteria
    func startLookingForDrivers () {
        
        let region = MKCoordinateRegion(center: mapView.centerCoordinate, span: mapView.region.span)
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("readyDrivers"))
        lookingForDriversInRegionQuery = geoFire.query(with: region)
        
        // a driver entered search region
        _ = lookingForDriversInRegionQuery?.observe(.keyEntered, with: { (key, location) in
            
            self.nearbyDrivers[key!] = location
            
            if let driverLocation = location as CLLocation!, let theKey = key as String! {
                
                if self.isDriverBeingDisplayed(theKey) {
                    
                    // move the annotaiton instead
                    self.moveDriverAnnotation(theKey, driverLocation.coordinate)
                    
                } else {
                    // add their annotation
                    let newDriverAnnotation:driverAnnotation = driverAnnotation.init(driverLocation.coordinate, theKey)
                    self.mapView.addAnnotation(newDriverAnnotation)
                }
            }
        })
        
        // a driver moved in region
        _ = lookingForDriversInRegionQuery?.observe(.keyMoved, with: { (key, location) in
            
            if let driverLocation = location as CLLocation!, let theKey = key as String! {
                
                self.moveDriverAnnotation(theKey, driverLocation.coordinate)
                print("Total Annotation \(self.mapView.annotations.count)")
            }
        })
        
        // a driver exited in region
        _ = lookingForDriversInRegionQuery?.observe(.keyExited, with: { (key, location) in
            
            self.nearbyDrivers.removeValue(forKey: key!)
            
            for annot in self.mapView.annotations {
                
                if annot.isMember(of: driverAnnotation.self) {
                    
                    if annot is driverAnnotation {
                        
                        self.mapView.removeAnnotation(annot)
                    }
                }
            }
        })
    }
    
    // driver method
    func startLookingForPassengers () {
        
        if currentLocation == nil { // this method is called very early on, and the device might not have a user location yet, call it again until we have the location
            
            Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(MapViewController.startLookingForPassengers), userInfo: nil, repeats: false)
            
        } else {
            
            // start watching this user's request directory
            
            watchingThisUsersDirectoryForPickupRequests = refThisUsersDirectory().child("requests").observe(.childAdded, with: { (requestInUserDirectorySnapshot) -> Void in
                
                if let limitedRequestInfo: NSDictionary = requestInUserDirectorySnapshot.value as? NSDictionary {
                    
                    // watch for change of status in the "limited" driver's directory
                    // todo add a check here to see if this is a new request, look at the status label to see
                    
                    let limitedStatus = limitedRequestInfo.object(forKey: "status") as! String
                    
                    if limitedStatus == "yours" { // this means it is a new pickup request!
                        
                        
                        // load info about the person and where they are going
                        let requestersUserID = limitedRequestInfo.object(forKey: "requestingUsersID") as! String
                        
                        let requestExpirationTime: Date = self.universalInternetDateFormatter().date(from: limitedRequestInfo.object(forKey: "requestExpiration") as! String)!
                    
                        
                        self.ref.child("users").child(requestersUserID).observeSingleEvent(of: .value, with: { (userSnapshot) in
                            
                            // get info about the user
                            let userSnapshotDictionary = userSnapshot.value as! NSDictionary
                            let personName = userSnapshotDictionary.object(forKey: "userType") as! String
                            
                            // get info about where the user would like to go to
                            let theRequestID = limitedRequestInfo.object(forKey: "theRequestID") as! String
                            self.ref.child("requests").child(theRequestID).child("location").observeSingleEvent(of: .value, with: { (locationSnapshot) in
                                
                                let locationDictionary = locationSnapshot.value as! NSDictionary
                                
                                let statusDirectory = self.ref.child("users").child(self.thisAppUserID).child("requests").child(requestInUserDirectorySnapshot.key).child(kStatus)
                                
                                self.pickupRequestUserUniqueID = requestInUserDirectorySnapshot.key
                                self.requestDirectoryRequestID = limitedRequestInfo.object(forKey: "theRequestID") as! String
                                
                                self.reactToUserChangesToThisRequest(limitedStatus, statusDirectory, personName, locationDictionary, requestersUserID, requestExpirationTime)
                                
                            })
                        })
                    }
                }
            })
        }
    }
    
    // driver method
    func reactToUserChangesToThisRequest (_ statusOfRequestForThisDriver: String,
                                          _ statusDirectory: FIRDatabaseReference,
                                          _ personName: String,
                                          _ locationDictionary: NSDictionary,
                                          _ requestersUserID: String,
                                          _ requestExpirationTime: Date) {
        
        statusDirectory.observe(.value, with: { (statusUpdateSnapshot) in
            
            let status = statusUpdateSnapshot.value as! String
            
            if status == "yours" {
                
                let passengerPickupLocation = CLLocation(latitude: locationDictionary.object(forKey: kLatitude) as! CLLocationDegrees, longitude: locationDictionary.object(forKey: kLongitude) as! CLLocationDegrees)
                
                let distanceToPassenger = passengerPickupLocation.distance(from: self.currentLocation)
                
                statusDirectory.parent?.updateChildValues([kStatus : "showing"], withCompletionBlock: { (error, ref) in
                    self.showPickupRequestView(personName, distanceToPassenger, requestExpirationTime)
                })
                
            } else if status == kAccepted {
                
                self.makeATrip(locationDictionary, requestersUserID)
                
            } else if status == kNoResponse {
                self.changePickupRequestViewToNoResponse()
                
            } else if status == kPassengerCancelled {
                self.view.sendSubview(toBack: self.pickupRequestView)
                
                // if trips directory exists, cancel the trip (it means the driver had accepted and was enroute)
                if self.theTripDirectory != nil {
                    
                    self.preformDriverCancellationOperations(whoCancelled: kPassengerCancelled)
                    
                } else {
                    self.showPassengerCancelledAlert()
                }
            }
        })
    }
    
    // driver method
    func showPickupRequestView (_ personName: String, _ distanceToPassenger: Double, _ requestExpirationTime: Date) {
        self.closeButton.isHidden = true
        self.passPassenger.isHidden = false
        self.acceptPassenger.isHidden = false
        
        let distanceMiles = distanceToPassenger * 0.000621371
        self.passengerName.text = "\(personName) is \(String(format: "%.1f", distanceMiles)) miles away"
        
        _ = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(updateCountdown), userInfo: requestExpirationTime, repeats: false)
        
        self.view.bringSubview(toFront: self.pickupRequestView)
    }
    
    // driver method
    func updateCountdown (_ timer: Timer) {
        
        let requestExpirationTime = timer.userInfo as! Date
        
        let seconds = Date().timeIntervalSince(requestExpirationTime)
        
        let secondsLeft = seconds * -1
        
        countdownLabel.text = "\(String(format: "%.0f", secondsLeft))"
        
        if secondsLeft > 0 {
            _ = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateCountdown), userInfo: requestExpirationTime, repeats: false)
        } else {
            countdownLabel.text = ""
        }
    }
    
    // driver method
    func changePickupRequestViewToNoResponse () {
        self.closeButton.isHidden = false
        self.passPassenger.isHidden = true
        self.acceptPassenger.isHidden = true
        self.passengerName.text = "Too Much Time Passed"
    }
    
    //driver and passenger method
    func displayDriverDrivingDirections (from fromLocation: CLLocationCoordinate2D, to toLocation: CLLocationCoordinate2D) {
        
        // remove the old route polygon
        removeRouteOverlays()
        
        // get directions to that person
        let drivingDirectionsRequest = MKDirectionsRequest()
        drivingDirectionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLocation))
        drivingDirectionsRequest.destination = MKMapItem.init(placemark: MKPlacemark(coordinate: toLocation))
        drivingDirectionsRequest.transportType = .automobile
        
        let drivingDirections = MKDirections(request: drivingDirectionsRequest)
        
        drivingDirections.calculate { (response, error) in
            if error == nil {
                
                if let unwrappedResponse = response {
                    
                    for route in unwrappedResponse.routes {
                        
                        self.mapView.add(route.polyline)
                        // todo the current method zooms to the path to closely.
                        /*
                         var routeRect = route.polyline.boundingMapRect
                         
                         routeRect.size.width += routeRect.size.width * 0.25
                         routeRect.size.height += routeRect.size.height * 0.25
                         
                         routeRect.origin.x -= routeRect.size.width / 2
                         routeRect.origin.y -= routeRect.size.height / 2
                         */
                        
                        
                        // self.mapView.setVisibleMapRect(routeRect, UIEdgeInsetsMake(20.0, 20.0, 20.0, 20.0), true)
                        //  self.mapView.setVisibleMapRect(routeRect, animated: true)
                        
                        //todo refactor the 1 and 0 to kConstants
                        if self.userStatusMode == Int(KmodeDriver) { // is driver
                            self.updateDriverEnrouteInfo(route)
                        }
                    }
                }
                
            } else {
                print("error getting directions")
            }
        }
    }
    
    
    // driver method
    func addPassengerPickupPin (_ passengerLocationForMap: CLLocationCoordinate2D) {
        
        let userLocation: passengerPickupLocationAnnotation = passengerPickupLocationAnnotation.init(passengerLocationForMap, "Pickup Location")
        mapView.addAnnotation(userLocation)
    }
    
    // driver method
    func updateDriverEnrouteInfo (_ route: MKRoute) {
        let updatedTravelInfo = [
            "eta" : route.expectedTravelTime,
            "distance" : route.distance
        ]
        self.ref.child("trips").child(self.theTripDirectory).child("travelInfo").updateChildValues(updatedTravelInfo)
    }
    
    // driver method
    func makeATrip (_ passengerRequestedLocation: NSDictionary, _ thePassengerID: String) {
        
        // make a new post in trip directory
        
        let post = [
            "driverId" : thisAppUserID,
            "passengerId" : thePassengerID,
            "initialDistanceToPassenger" : "WhoKnows...",
            "status" : "driverEnroute",
            "timeStamp" : self.getCurrentTime(),
            "userStartingLocation" : passengerRequestedLocation
            ] as [String : Any]
        
        
        self.ref.child("trips").childByAutoId().updateChildValues(post, withCompletionBlock: { (error, reference) in
            // add the unique id of this trip to each of their user directories
            
            self.theTripDirectory = reference.key
            
            self.ref.child("users").child(self.thisAppUserID).child("trips").updateChildValues([reference.key : reference.key])
            self.ref.child("users").child(thePassengerID).child("trips").updateChildValues([reference.key : reference.key])
            
            let passengerLocationForMap: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: passengerRequestedLocation.object(forKey: kLatitude) as! CLLocationDegrees, longitude: passengerRequestedLocation.object(forKey: kLongitude) as! CLLocationDegrees)
            
            self.displayDriverDrivingDirections(from: self.currentLocation.coordinate, to: passengerLocationForMap)
            self.addPassengerPickupPin(passengerLocationForMap)
            self.updateDriverUIForEnroute()
        })
    }
    
    // driver method
    func updateDriverUIForEnroute () {
        
        self.addressLabel.text = "Follow the route to the Passenger."
        
        self.cancelButton.setTitle("Cancel Passenger Pickup", for: .normal)
        self.view.bringSubview(toFront: self.cancelButton)
        
        self.view.bringSubview(toFront: onTripButton)
        onTripButton.setTitle("Pickup Passenger", for: .normal)
    }
    
    // driver and passenger method
    // displays driving directions for driver
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.strokeColor = UIColor.blue
        renderer.lineWidth = 2.0
        return renderer
    }
    
    // driver method
    @IBAction func passUserRequestToAnotherDriver (_ sender: Any) {
        refThisUsersDirectory().child("requests").child(pickupRequestUserUniqueID).updateChildValues([kStatus: kPassed])
        closeRequestView()
    }
    
    // driver method
    @IBAction func acceptPassengerRequest (_ sender: Any) {
        
        moveToEnrouteDriver()
        
        refThisUsersDirectory().child("requests").child(pickupRequestUserUniqueID).updateChildValues([kStatus: kAccepted])
        
        // update the request in the main request directory
        ref.child("requests").child(requestDirectoryRequestID).updateChildValues([kStatus: kAccepted])
        
        closeRequestView()
    }
    
    // driver method
    @IBAction func closePassengerRequestView (_ sender: Any) {
        closeRequestView()
    }
    // driver method
    func closeRequestView () {
        self.view.sendSubview(toBack: self.pickupRequestView)
    }
    
    // driver and passenger method
    func ifLookingForPassengerThenStop () {
        
        if userStatusMode == Int(KmodeDriver) {
            stopLookingForPassengers()
        }
    }
    
    // todo have the app, after being close be able to resume status. eg  the drier is still enroute, or on a trip... this allows app switching
    // driver method
    func moveToEnrouteDriver ()  {
        
        stopLookingForPassengers()
        
        isEnroute = true
        
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("enrouteDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.setLocation(currentLocation, forKey: appUserID)
    }
    
    // driver method
    func moveFromEnrouteDriverToActiveDriver () {
        
        isEnroute = false
        
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("enrouteDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.removeKey(appUserID)
        
        // this puts the driver back in active-driver status
        updateDriverLocationInDatabase ()
    }
    
    // driver method
    func moveFromEnrouteDriverToDriverDriver () {
        isEnroute = false
        
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("enrouteDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.removeKey(appUserID)
        
        updateDriverDrivingPassenger()
    }
    
    // todo not currently called, yet
    // driver method
    func moveFromDrivingDriver()  {
        
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("drivingDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.removeKey(appUserID)
    }
    
    // driver and passenger method (called when switching between user modes)
    func stopLookingForPassengers() {
        
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("readyDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.removeKey(appUserID)
        
        nearbyDrivers = [:]
        
        if watchingThisUsersDirectoryForPickupRequests != nil {
            // stop watching this user's request directory for new pickup requests
            ref.removeObserver(withHandle: watchingThisUsersDirectoryForPickupRequests)
        }
        
        if watchingMainRequestDirectoryForPickupRequests != nil {
            ref.removeObserver(withHandle: watchingMainRequestDirectoryForPickupRequests)
        }
    }
    
    
    // mapview delegates
    // passenger and driver method
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        if zoomedToInitialLocation {
            
            let theLocation = CLLocation(latitude:mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
            
            updateAddressLabel(theLocation)
            
            if onATrip() == false {
                
                stopLookingForDrivers () // in the old region
                startLookingForDrivers() // in the new region
            }
        }
    }
    
    // passenger and driver method
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is driverAnnotation {
            
            let driverAnnotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "driver")
            driverAnnotationView.image = UIImage(named: "car")
            return driverAnnotationView
            
        } else {
            return nil
        }
    }
    
    // driver method
    func onATrip () -> Bool {
        
        if theTripDirectory == nil {
            return false
        } else {
            return true
        }
    }
    
    // driver method
    func endATrip() {
        theTripDirectory = nil
    }
    
    // driver method
    func driverIsEnroute() -> Bool {
        return isEnroute
    }
    
    // driver and passenger method
    func updateAddressLabel(_ location: CLLocation) {
        
        if userStatusMode == Int(KmodePassanger) && activeRequestPath == nil {
            
            CLGeocoder().reverseGeocodeLocation(location) { (placemarks, error) in
                
                if error != nil {
                    print(error ?? "Unknown Error")
                } else {
                    
                    let placeMark: CLPlacemark!
                    placeMark = placemarks?[0]
                    
                    var addressString = ""
                    
                    if let locationName = placeMark.addressDictionary!["Name"] as? String {
                        addressString.append("\(locationName)\n")
                    }/*
                     if let street = placeMark.addressDictionary!["Thoroughfare"] as? String {
                     addressString.append("\(street)\n")
                     }*/
                    if let city = placeMark.addressDictionary!["City"] as? String {
                        addressString.append("\(city) ")
                    }
                    if let zip = placeMark.addressDictionary!["ZIP"] as? String {
                        addressString.append("\(zip)")
                    }
                    
                    self.addressLabel.text = addressString as String
                }
            }
        }
    }
    
    // driver and passenger method
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let theLocation = locations.last!
        
        if theLocation.horizontalAccuracy < 100 {
            
            currentLocation = theLocation
            
            if zoomedToInitialLocation == false {
                
                let mapCenter = CLLocationCoordinate2D(latitude: currentLocation.coordinate.latitude, longitude: currentLocation.coordinate.longitude)
                
                let region = MKCoordinateRegion(center: mapCenter, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapView.setRegion(region, animated: true)
                
                zoomedToInitialLocation = true
                
                // update the label this time
                updateAddressLabel(currentLocation)
                
            } else {
                
                // if in driver mode, update the database with that person's location
                /// todo mode is now unncessary, remove it
                // driver only sub-section
                if let mode = userStatusMode, mode == 1 {
                    
                    if onATrip() {
                        
                        if driverIsEnroute() {
                            updateEnrouteDriverPosition()
                        } else {
                            updateDriverDrivingPassenger()
                        }
                    } else {
                        updateDriverLocationInDatabase()
                    }
                }
            }
        }
    }
    
    // driver method
    func updateDriverLocationInDatabase() {
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("readyDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.setLocation(currentLocation, forKey: appUserID)
    }
    
    // driver method
    func updateEnrouteDriverPosition() {
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("enrouteDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.setLocation(currentLocation, forKey: appUserID)
    }
    
    // driver method
    func updateDriverDrivingPassenger() {
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("drivingDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.setLocation(currentLocation, forKey: appUserID)
    }
    
    // driver and passenger method
    func getCurrentTime() -> String {
        
        let theDate = Date()
        return universalInternetDateFormatter().string(from: theDate)
    }
    
    // passenger method
    func getExpirationTime (addTime secondsToAdd: Double) -> String {
        
        var theDate = Date()
        theDate.addTimeInterval(secondsToAdd)
        return universalInternetDateFormatter().string(from: theDate)
    }
    
    // passenger method
    @IBAction func requestButtonPressed(_ sender: Any) {
        
        if self.driversAreNearBy() {
            
            driversThatPassed = [:] // reset this dictionary, as no drivers have passed on this new request yet
            
            requestButton.isEnabled = false
            
            let attemptToPostRequest =  ref.child("requests").childByAutoId()
            
            pickupLocation = [
                kLatitude : self.mapView.centerCoordinate.latitude,
                kLongitude : self.mapView.centerCoordinate.longitude
            ]
            
            let postDictionary = [
                "status" : "requested",
                "location" : pickupLocation,
                "timeStamp" : self.getCurrentTime(),
                "userType" : "anonymous"
                ] as [String : Any]
            
            attemptToPostRequest.updateChildValues(postDictionary, withCompletionBlock: { (error, requestReference) in
                
                if error == nil {
                    
                    self.activeRequestPath = requestReference
                    self.view.bringSubview(toFront: self.cancelButton)
                    
                    self.sendPickUpRequestToNearbyDrivers()
                    
                } else { // error
                    self.requestButton.isEnabled = true
                    self.activeRequestPath = nil
                }
            })
            
            let userLocation: passengerPickupLocationAnnotation = passengerPickupLocationAnnotation.init(mapView.centerCoordinate, "Pickup Location")
            mapView.addAnnotation(userLocation)
            
            self.startListeningForDriversToAcceptPickupRequest()
            
        } else {
            showNoNearbyDriversGUIUpdate()
        }
    }
    
    // passenger method
    func showNoNearbyDriversGUIUpdate () {
        
        self.removePassengerPickupLocationAnnotation()
        
        let alert = UIAlertController(title: "Sorry", message: "There are no available drivers nearby.", preferredStyle: .alert)
        let closeButton = UIAlertAction(title: "Close", style: .destructive, handler: nil)
        alert.addAction(closeButton)
        self.present(alert, animated: true, completion: nil)
    }
    
    
    // todo reintroduce this thought the code for a cleaner experience, do this for similar types of frequently user references
    // driver and passenger method
    func refThisUsersDirectory () -> FIRDatabaseReference {
        return ref.child("users").child(thisAppUserID)
    }
    
    // passenger method
    // todo next, refactor this
    func startListeningForDriversToAcceptPickupRequest () {
        
        refThisUsersDirectory().child("trips").observe(.childAdded, with: { (tripSnapshot) in
            
            let tripKey: String =  tripSnapshot.value as! String
            
            // todo it is so silly because it calls this for each trip, even the old ones... lets move trips into an "old trips" dir in the user dir
            
            self.ref.child("trips").child(tripKey).observe(.value, with: { (fullTripDataSnapshot) in
                
                if let tripDictionary = fullTripDataSnapshot.value as? NSDictionary {
                    
                    if let status: String = tripDictionary.object(forKey: "status") as? String {
                        
                        if status == "driverEnroute" {
                            // show an alert that the driver is coming
                            
                            
                            if let shownAlert = tripDictionary.object(forKey: "alertedPassengerDriverEnroute") as? Bool, shownAlert == true  {
                                
                            } else {
                                
                                self.noResponseTimer.invalidate()
                                
                                self.ref.child("trips").child(tripKey).updateChildValues(["alertedPassengerDriverEnroute" : true])
                                
                                let driverID: String = tripDictionary.object(forKey: "driverId") as! String
                                /*
                                 
                                 let newTripAlert = UIAlertController(title: "Driver Enroute", message: "With ID: \(driverID)", preferredStyle: .alert)
                                 
                                 let closeAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                                 newTripAlert.addAction(closeAction)
                                 
                                 self.present(newTripAlert, animated: true, completion: nil)
                                 */
                                self.stopLookingForDrivers()
                                
                                self.showDriverOnMapEnrouteToPassenger(driverID, tripDictionary.object(forKey:"userStartingLocation") as! NSDictionary)
                                self.startListeningToUpdatesFromDriver(tripKey)
                            }
                            
                            
                        } else if status == kDriverCancelled {
                            
                            if let alreadyAlerted = tripDictionary.object(forKey: "userAlertedOfCancelledTrip") as? Bool, alreadyAlerted {
                                
                                // do nothing, the user has already seen the alert
                                
                            } else {
                                
                                self.ref.child("trips").child(tripKey).updateChildValues(["userAlertedOfCancelledTrip" : true])
                                
                                let alert = UIAlertController(title: "Driver Cancelled", message: "Sorry about that! Please make a new pickup request.", preferredStyle: .alert)
                                let close = UIAlertAction(title: "Close", style: .default, handler: nil)
                                alert.addAction(close)
                                self.present(alert, animated: true, completion: nil)
                                
                                
                                self.activeRequestPath = nil
                                self.view.bringSubview(toFront: self.requestButton)
                                self.requestButton.isEnabled = true
                                
                                self.addressLabel.text = ""
                                
                                self.removeRouteGUI()
                            }
                        } else if status == kPickedUpPassenger {
                            
                            if let pickedUp = tripDictionary.object(forKey: "passengerDeviceHasBeenPickedUp") as? Bool, pickedUp == true  {
                                
                            } else {
                                
                                self.ref.child("trips").child(tripKey).updateChildValues(["passengerDeviceHasBeenPickedUp" : true])
                                
                                if self.watchDriverForPickup != nil {
                                    self.ref.removeObserver(withHandle: self.watchDriverForPickup)
                                }
                                
                                self.view.sendSubview(toBack: self.cancelButton)
                                self.cancelButton.isEnabled = false
                                
                                // remove the enroute overlay but keep the pickup location pin
                                self.removeRouteOverlays()
                                
                                self.view.sendSubview(toBack: self.requestButton)
                                
                                
                                // set passenger UI for the trip
                                self.addressLabel.text = "Enroute To Your Destination"
                                
                                
                                // todo move requests to "old request" dir
                                self.activeRequestPath = nil
                                
                                self.view.bringSubview(toFront: self.blankButton)
                                
                                // todo draw polygon of the route to the passenger destination
                            }
                            
                        } else if status == kPassengerDroppedOff {
                            
                            if let droppedOff = tripDictionary.object(forKey: "passengerDeviceHasBeenDroppedOff") as? Bool, droppedOff == true  {
                                
                            } else {
                                
                                self.ref.child("trips").child(tripKey).updateChildValues(["passengerDeviceHasBeenDroppedOff" : true])
                                
                                
                                // get them ready to take another trip
                                
                                self.startLookingForDrivers()
                                
                                let centerOfMap = CLLocation(latitude:self.mapView.centerCoordinate.latitude, longitude: self.mapView.centerCoordinate.longitude)
                                
                                self.updateAddressLabel(centerOfMap)
                                
                                self.requestButton.isEnabled = true
                                self.view.bringSubview(toFront: self.requestButton)
                                
                                self.removeRouteGUI()
                                
                                // todo prompt the passenger to rate the driver
                                
                            }
                        }
                    }
                }
            })
        })
    }
    
    
    // passenger method
    func startListeningToUpdatesFromDriver (_ tripKey: String) {
        
        // when on a trip, listen for updates from the driver about when s/he is arriving
        self.ref.child("trips").child(tripKey).child("travelInfo").observe(.value, with: { (travelInfoSnapshot) in
            
            if let tripInfoDictionary = travelInfoSnapshot.value as? NSDictionary {
                
                let etaSeconds = tripInfoDictionary.object(forKey: "eta") as! Int
                let etaMinutes = Double(etaSeconds) / 60
                
                let distanceMeters = tripInfoDictionary.object(forKey: "distance") as! Int
                let distanceMiles = Double(distanceMeters) * 0.000621371
                
                var minutesPl: String
                
                if etaMinutes < 2 {
                    minutesPl = "minute"
                } else {
                    minutesPl = "minutes"
                }
                
                self.addressLabel.text = "Driver Enroute\n ETA: \(String(format: "%.0f", etaMinutes)) \(minutesPl)\n Distance: \(String(format: "%.1f", distanceMiles)) Miles"
            }
        })
    }
    
    // passenger method
    func driversAreNearBy () -> Bool {
        if nearbyDrivers.count > 0 {
            return true
        } else {
            return false
        }
    }
    
    // passenger method
    func sendPickUpRequestToNearbyDrivers () {
        
        if activeRequestPath == nil {
            
        } else {
            
            let post = [
                "requestingUsersID" : thisAppUserID,
                "status" : "yours",
                "theRequestID": activeRequestPath.key,
                "requestExpiration" : getExpirationTime(addTime: 20)
            ]
            
            let nearestDriver = findNearestAvailableDriver()
            
            print ("nearest drier to ask \(nearestDriver)")
            
            if nearestDriver != kEveryonePassed {
                
                ref.child("users").child(nearestDriver).child("requests").childByAutoId().updateChildValues(post) { (error, ref) in
                    
                    if error == nil {
                        
                        self.activeDriverUserRequestPath = ref
                        self.startListeningForIfDriverPassed(nearestDriver, ref.key)
                        
                        self.startWaitingForDriverTimer(nearestDriver, ref.key)
                    }
                }
            } else {
                self.showNoNearbyDriversGUIUpdate()
                
                // update the request in the main directory that everyone passed
                activeRequestPath.updateChildValues([kStatus : kEveryonePassed], withCompletionBlock: { (error, ref) in
                    
                    if error == nil {
                        self.activeRequestPath = nil
                        
                        self.view.bringSubview(toFront: self.requestButton)
                        self.requestButton.isEnabled = true
                    }
                })
            }
        }
    }
    
    // passenger method
    func startWaitingForDriverTimer(_ nearestDriverID: String, _ requestReference: String) {
        
        noResponseTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { (Timer) in
            
            // it is now too late to accept the request
            
            if self.activeRequestPath == nil {
                
            } else {
                self.ref.child("users").child(nearestDriverID).child("requests").child(requestReference).updateChildValues([kStatus: kNoResponse], withCompletionBlock: { (error, ref) in
                    
                    // alert driver it is too late, once successful then update the passenger
                    
                    self.driversThatPassed[nearestDriverID] = nearestDriverID
                    self.sendPickUpRequestToNearbyDrivers()
                }
                )}
        }
    }
    
    // passenger method
    func startListeningForIfDriverPassed (_ nearestDriverID: String, _ requestReference: String) {
        
        ref.child("users").child(nearestDriverID).child("requests").child(requestReference).child("status").observe(.value, with: { (snapshot) in
            
            if let status = snapshot.value as? String, status == kPassed {
                
                // add this driver id to the list of those who have passed this pickup
                self.driversThatPassed[nearestDriverID] = nearestDriverID
                self.sendPickUpRequestToNearbyDrivers()
            }
        })
    }
    
    // passenger method
    func findNearestAvailableDriver() -> String {
        
        var closestDistance = Double.greatestFiniteMagnitude
        var closestDriverKey = kEveryonePassed
        
        for possibleDriver in nearbyDrivers {
            
            // has this driver already been asked, but decided to pass?
            if let _ = driversThatPassed[possibleDriver.key] {
                
                // this driver already passed up the opportunity to pick up this passenger
                
            } else {
                
                let possibleDriverLocation =  possibleDriver.value as! CLLocation
                
                let destinationLocation = CLLocation(latitude: pickupLocation[kLatitude]!, longitude: pickupLocation[kLongitude]!)
                
                let distance = destinationLocation.distance(from: possibleDriverLocation)
                
                if distance < closestDistance {
                    closestDistance = distance
                    closestDriverKey = possibleDriver.key
                }
            }
        }
        return closestDriverKey
    }
    
    // driver and passenger method
    func removeRouteGUI () {
        removePassengerPickupLocationAnnotation()
        removePassengerDestinationLocationAnnotation()
        removeRouteOverlays()
    }
    
    // driver and passenger method
    func removePassengerPickupLocationAnnotation () {
        for annotation in mapView.annotations {
            if annotation is passengerPickupLocationAnnotation {
                mapView.removeAnnotation(annotation)
            }
        }
    }
    
    // driver and passenger method
    func removePassengerDestinationLocationAnnotation () {
        for annotation in mapView.annotations {
            if annotation is passengerDestinationLocationAnnotation {
                mapView.removeAnnotation(annotation)
            }
        }
    }
    
    // driver and passenger method
    func cancelRide() {
        
        removeRouteGUI()
        
        if userStatusMode == Int(KmodePassanger) {
            
            activeRequestPath.updateChildValues(["status" : kPassengerCancelled], withCompletionBlock: { (error, ref) in
                
                if error == nil {
                    
                    // update the driver request directory
                    self.activeDriverUserRequestPath.updateChildValues(["status" : kPassengerCancelled])
                    
                    self.activeRequestPath = nil
                    
                    self.view.bringSubview(toFront: self.requestButton)
                    self.requestButton.isEnabled = true
                }
            })
            
        } else { // is driver
            preformDriverCancellationOperations(whoCancelled: kDriverCancelled)
        }
    }
    
    // driver method
    func preformDriverCancellationOperations (whoCancelled canceller: String) {
        
        self.view.sendSubview(toBack: onTripButton)
        
        //// update Database
        // update the enrouteDriver to not include me, put me back on ready drivers
        moveFromEnrouteDriverToActiveDriver()
        
        // cancel this in trips/theTripDirectory
        ref.child("trips").child(theTripDirectory).updateChildValues(["status" : canceller])
        // use and observer there to alert the passenger that the drive was canceled
        endATrip()
        
        // /requests/requestDirectoryRequestId  status to DriverCanceledEnroute
        ref.child("requests").child(requestDirectoryRequestID).updateChildValues(["status" : canceller])
        requestDirectoryRequestID = nil
        
        if canceller == kDriverCancelled {
            
            // let thisAppUserID = UserDefaults.standard.object(forKey: kAppUserID) as! String
            
            // users/self/requests/pickuprequestuseridstring/status to DriverCanceledEnroute
            refThisUsersDirectory().child("requests").child(pickupRequestUserUniqueID).updateChildValues(["status" : kDriverCancelled])
            pickupRequestUserUniqueID = nil
            
        } else if canceller == kPassengerCancelled {
            
            showPassengerCancelledAlert()
        }
        
        
        //// update the UI
        
        if userStatusMode == Int(KmodePassanger) { // passenger
            let centerOfMap = CLLocation(latitude: pickupLocation[kLatitude]!, longitude: pickupLocation[kLongitude]!)
            updateAddressLabel(centerOfMap)
            
        } else { // driver
            addressLabel.text = ""
        }
        
        removeRouteGUI()
        
        // switch back to the looking for passengers button
        self.view.sendSubview(toBack: self.cancelButton)
        
        // re-center on the driver
        let centerOnUser = MKCoordinateRegion(center: currentLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        
        mapView.setRegion(centerOnUser, animated: true)
    }
    
    // driver and passenger method
    func removeRouteOverlays () {
        for overlay in mapView.overlays {
            mapView.remove(overlay)
        }
    }
    
    // driver method
    func showPassengerCancelledAlert () {
        
        let alert = UIAlertController(title: "Passenger Cancelled", message: "Sorry, but the passenger cancelled", preferredStyle: .alert)
        let close = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(close)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    // diver and passanger method
    @IBAction func cancelButtonPressed(_ sender: Any) {
        cancelRide()
    }
    
    // todo finish writing me and also call me
    // todo not called yet
    func pickupPassengerAndStartTheirTrip () {
        isEnroute = false
        
    }
    //todo add alert view asking if the user or driver really wants to cancel the ride
    
    
    // driver method
    @IBAction func startDrivingWithPassenger () {
        
        //// update database
        // update driver location
        moveFromEnrouteDriverToDriverDriver()
        
        ref.child("trips").child(theTripDirectory).updateChildValues([kStatus : kPickedUpPassenger])
        
        // tell passenger to do this, ad a listen for trip status
        
        // update the ui
        addressLabel.text = "Drive to final destination"
        
        self.removeRouteOverlays()
        
        // hide the pickup passenger button
        self.view.sendSubview(toBack: onTripButton)
        
        // show finish ride button
        self.view.bringSubview(toFront: completeTripButton)
        
        
        // todo navigate driver to user destination
    }
    
    // driver method
    @IBAction func completeTrip () {
        
        // update database
        ref.child("trips").child(theTripDirectory).updateChildValues([kStatus : kPassengerDroppedOff])
        
        endATrip()
        
        // update UI
        self.view.sendSubview(toBack: completeTripButton)
        self.view.bringSubview(toFront: requestButton)
        
        removeRouteGUI()
        
        self.addressLabel.text = ""
        
        let alert = UIAlertController(title: "Another Drive?", message: "Start looking for another pickup?", preferredStyle: .alert)
        
        let moreDriving = UIAlertAction(title: "Another Pickup", style: .default, handler: { _ in
            self.startLookingForPassengers()
            self.updateDriverLocationInDatabase() // move driver back onto active list
            
        })
        
        let stopDriving = UIAlertAction(title: "No More Pickups", style: .destructive, handler: { _ in
            self.requestButton.setTitle("Not Looking For Passengers", for: .normal)
        })
        
        alert.addAction(moreDriving)
        // alert.addAction(stopDriving)
        
        self.present(alert, animated: true)
        
        // todo prompt driver to rate passenger
    }
    
    
    // MARK Utility Methods
    
    // driver and passenger method
    func universalInternetDateFormatter () -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale!
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        return formatter
    }

    
    
    /*
     func showTutorial () {
     
     let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
     _ = storyboard.instantiateViewController(withIdentifier: "tutorialNav")
     
     
     let initialViewController: UINavigationController = storyboard.instantiateViewController(withIdentifier: "tutorialNav") as! UINavigationController
     
     
     self.present(initialViewController, animated: true, completion: nil)
     }
     */
    
    
    // bug if you make a request, it is accepted, you cancel it and then request a new one, it says no drivers available, because the database requires the map to move to reference it... perhaps just clear the driversThatPassed dictionary once you are on a trip, (nope that already resets, when you press request button...)

    
}

