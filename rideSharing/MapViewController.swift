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


// bug if you make a request, it is accepted, you cancel it and then request a new one, it says no drivers avilable, becaues the datbase require the map to move to refrece it... perhsps jsut clear the driversThatPassed dirctionary once you are on a trip, (nope that already resets, when you press request button...)

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {

    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var requestButton: UIButton!
    @IBOutlet weak var centerButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    
    // UI in the pickup request screen
    @IBOutlet weak var pickupRequestView: UIView!
    @IBOutlet weak var acceptPassanger: UIButton!
    @IBOutlet weak var passPassanger: UIButton!
    @IBOutlet weak var passangerName: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var onTripButton: UIButton!
    @IBOutlet weak var completeTripButton: UIButton!
    @IBOutlet weak var countdownLabel: UILabel!
    
    @IBOutlet weak var blankButton: UIButton!
    
    let locationManager = CLLocationManager()
    var currentLocation: CLLocation!
    
    var zoomedToInitialLocation = false
    
    var ref: FIRDatabaseReference!
    
    var geoCoder: CLGeocoder!
    
    var activeRequestPath: FIRDatabaseReference!
    var activeDriverUserRequestPath: FIRDatabaseReference!
    
    var nearbyDrivers: [String: Any] = [:]
    var userStatusMode: Int!
    
    var pickupRequestUserUniqueID: String!
    var requestDirectoryRequestID: String!
    var theTripDirectory: String!
    
    var lookingForDriversInRegionQuery: GFRegionQuery!
    var watchDriverForPickup: FIRDatabaseHandle!

    var isEnroute: Bool!
    var watchingThisUsersDirectoryForPickupRequests: FIRDatabaseHandle!
    var watchingMainRequestDirectoryForPickupRequests: FIRDatabaseHandle!
    
    var driversThatPassed: [String: String] =  [:]
    
    var noResponceTimer: Timer!
    var pickupLocation: [String: CLLocationDegrees] = [:]
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        ref = FIRDatabase.database().reference()

        setupGUI()
        
        if isUserProfileReady() {
            setupMapViewController()
          
        } else {
            NotificationCenter.default.addObserver(self, selector: #selector(MapViewController.userProfileCreated), name: NSNotification.Name("userProfileCreated"), object: nil)
        }

        NotificationCenter.default.addObserver(self, selector: #selector(MapViewController.ifLookingForPassangerThenStop), name: NSNotification.Name("closingApp"), object: nil)
    }
    
    
    func isUserProfileReady() -> Bool {
        if let _ = UserDefaults.standard.string(forKey: kAppUserID) as String? {
            return true
        } else {
            return false
        }
    }
    
    func setupMapViewController () {
        setupUserTypeSwitching()
        setupLocationManager()
    }

    
    func userProfileCreated () {
        setupMapViewController()
    }
    
    @IBAction func settingsButtonTapped (_ sender: Any) {
        
        self.performSegue(withIdentifier: "settings", sender: nil)
    }
    
    func setupUserTypeSwitching () {
    
        NotificationCenter.default.addObserver(self, selector: #selector(MapViewController.updateStatus), name: NSNotification.Name("changedUserStatus"), object: nil)
        
        userStatusMode = UserDefaults.standard.integer(forKey: kUserStatusMode)
        
        NotificationCenter.default.post(name: NSNotification.Name("changedUserStatus"), object: userStatusMode)
    }
    
    func updateStatus (_ theNotification: NSNotification) {
    
        let userStatus = theNotification.object as! Int
        userStatusMode = userStatus
        
        let defaults = UserDefaults.standard
        defaults.set(userStatus, forKey: kUserStatusMode)
        defaults.synchronize()
                
        
        if userStatus == 0 {
        // passanger
            requestButton.isEnabled = true
            requestButton.setTitle("Request Pickup", for: .normal)
            centerButton.isHidden = false
            addressLabel.text = "Loading Address"

            stopLookingForPassangers()
            
        } else {
        // driver
            requestButton.setTitle("Looking For Passangers", for: .normal)
            centerButton.isHidden = true
            requestButton.isEnabled = false
            addressLabel.text = ""

            // did the user request a ride before switching?
            if activeRequestPath != nil {
                cancelRide()
            }
            
            startLookingForPassangers()
            updateDriverLocationInDatabase()
        }
    }
    
    
    func setupLocationManager () {
        
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.authorizedWhenInUse {
            locationManager.requestWhenInUseAuthorization()
        }
        
        locationManager.delegate = self
        locationManager.distanceFilter = 5
        locationManager.startUpdatingLocation()
    }
    
    
    func setupGUI () {
        self.view.sendSubview(toBack: onTripButton)
        self.view.sendSubview(toBack: cancelButton)
        self.view.sendSubview(toBack: pickupRequestView)
        self.view.sendSubview(toBack: completeTripButton)
        self.view.sendSubview(toBack: blankButton)
    }
    
    
    func removeAllDriverAnnotations () {
    
        for annotation in mapView.annotations {
            if annotation is driverAnnotation {
                mapView.removeAnnotation(annotation)
            }
        }
    
    }
    
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
    
    
    func stopLookingForDrivers () {
        
        // stop the geofire queries looking for drivers
        if lookingForDriversInRegionQuery != nil {
            lookingForDriversInRegionQuery.removeAllObservers()
        }
        // remove all driver pins
        removeAllDriverAnnotations()
    }
    
    
    func showDriverOnMapEnrouteToPassanger (_ driverID: String, _ passangerPickupLocationDictionary: NSDictionary) {
        
        let passangerPickupLocationCoor = CLLocationCoordinate2D(latitude: passangerPickupLocationDictionary.object(forKey: kLatitude) as! CLLocationDegrees, longitude: passangerPickupLocationDictionary.object(forKey: kLongitude) as! CLLocationDegrees)

        watchDriverForPickup = ref.child("enrouteDrivers").child(driverID).observe(.value, with: { (locationSnapshot) in
            
            if let locationDictionary = locationSnapshot.value as? NSDictionary {
            
                if let locationArray = locationDictionary.object(forKey: "l") as? NSArray {
                    
                    let driverLocation: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: locationArray[0] as! CLLocationDegrees, longitude: locationArray[1] as! CLLocationDegrees)
                    
                    if self.isDriverBeingDisplayed(driverID) {
                        
                        self.moveDriverAnnotation(driverID, driverLocation)
                        
                        self.displayDriverDrivingDirections(from: driverLocation, to: passangerPickupLocationCoor)
                        
                    } else { // add their annotation
                        
                        let newDriverAnnotation:driverAnnotation = driverAnnotation.init(driverLocation, driverID)
                        
                        self.mapView.addAnnotation(newDriverAnnotation)
                        self.displayDriverDrivingDirections(from: driverLocation, to: passangerPickupLocationCoor)

                        
                    }
                }
            }
        })
    }
    
    
    // did region change, then update these stuff
    func startLookingForDrivers () {
        
        let region = MKCoordinateRegion(center: mapView.centerCoordinate, span: mapView.region.span)
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("readyDrivers"))
        lookingForDriversInRegionQuery = geoFire.query(with: region)
        
        //driver entered region
         _ = lookingForDriversInRegionQuery?.observe(.keyEntered, with: { (key, location) in
         
            self.nearbyDrivers[key!] = location

            if let driverLocation = location as CLLocation!, let theKey = key as String! {

                if self.isDriverBeingDisplayed(theKey) {
                
                    // move it instead
                    self.moveDriverAnnotation(theKey, driverLocation.coordinate)
                    
                } else {
                    // add their annotation
                    let newDriverAnnotation:driverAnnotation = driverAnnotation.init(driverLocation.coordinate, theKey)
                    self.mapView.addAnnotation(newDriverAnnotation)
                }
            }
         })
   
        // driver moved in region
        _ = lookingForDriversInRegionQuery?.observe(.keyMoved, with: { (key, location) in
            
            if let driverLocation = location as CLLocation!, let theKey = key as String! {

                self.moveDriverAnnotation(theKey, driverLocation.coordinate)
                print("Total Annotation \(self.mapView.annotations.count)")
            }
        })
        
        // driver exited in region
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
    
    
    // driver- method
    func startLookingForPassangers () {

        if currentLocation == nil { // this method is called very early on, and the device mightnot have a user location yet
            
            Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(MapViewController.startLookingForPassangers), userInfo: nil, repeats: false)
            
        } else {
            
            let thisAppUserID = UserDefaults.standard.object(forKey: kAppUserID) as! String
        
            // start watching this user's request directory

            watchingThisUsersDirectoryForPickupRequests = ref.child("users").child(thisAppUserID).child("requests").observe(.childAdded, with: { (requestInUserDirectorySnapshot) -> Void in
                
            if let limitedRequestInfo: NSDictionary = requestInUserDirectorySnapshot.value as? NSDictionary {
            
                // watch for change of status in the limited directory
                
                // todo add a check here to see if this is a new request, look at the status label to see
                
                let limitedStatus = limitedRequestInfo.object(forKey: "status") as! String
                
                
                // this means it is a new pickup request!
                
                if limitedStatus == "yours" {
                    
                    
                    // load info about the person and where they are going
                    let requestersUserID = limitedRequestInfo.object(forKey: "requestingUsersID") as! String
    
                   // let requestExpirationTimeString = limitedRequestInfo.object(forKey: "requestExpiration") as! String
                    
                    
                   // let theDate = Date()
                    let formatter = DateFormatter()
                    formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale!
                    formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
                    
                    let requestExpirationTime: Date = formatter.date(from: limitedRequestInfo.object(forKey: "requestExpiration") as! String)!
                    
                 //   return formatter.string(from: theDate)
                    
                    
                    self.ref.child("users").child(requestersUserID).observeSingleEvent(of: .value, with: { (userSnapshot) in
                        
                        // get info about the user
                        let userSnapshotDictionary = userSnapshot.value as! NSDictionary
                        let personName = userSnapshotDictionary.object(forKey: "userType") as! String
                        
                        // get info about where the user would like to go to
                        let theRequestID = limitedRequestInfo.object(forKey: "theRequestID") as! String
                        self.ref.child("requests").child(theRequestID).child("location").observeSingleEvent(of: .value, with: { (locationSnapshot) in
                            
                            let locationDictionary = locationSnapshot.value as! NSDictionary

                            let statusDirectory = self.ref.child("users").child(thisAppUserID).child("requests").child(requestInUserDirectorySnapshot.key).child(kStatus)
                            
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
            
                let passangerPickupLocation = CLLocation(latitude: locationDictionary.object(forKey: kLatitude) as! CLLocationDegrees, longitude: locationDictionary.object(forKey: kLongitude) as! CLLocationDegrees)
                
                let distanceToPassanger = passangerPickupLocation.distance(from: self.currentLocation)
                
                statusDirectory.parent?.updateChildValues([kStatus : "showing"], withCompletionBlock: { (error, ref) in
                    self.showPickupRequestView(personName, distanceToPassanger, requestExpirationTime)
                })
                
            } else if status == kAccepted {
              
                self.makeATrip(locationDictionary, requestersUserID)
                
            } else if status == kNoResponce {
                self.changePickupRequestViewToNoResponce()
                
            } else if status == kPassengerCancelled {
                self.view.sendSubview(toBack: self.pickupRequestView)
                
                // if trips driectory exists, cancel the trip (it means the driver had accepted and was enroute)
                if self.theTripDirectory != nil {
                    
                    self.preformDriverCancellationOperations(whoCancelled: kPassengerCancelled)
                    
                } else {
                    self.showPassangerCancelledAlert()
                }
            }
        })
    }
    
    
    func showPickupRequestView (_ personName: String, _ distanceToPassanger: Double, _ requestExpirationTime: Date) {
        self.closeButton.isHidden = true
        self.passPassanger.isHidden = false
        self.acceptPassanger.isHidden = false
        
        let distanceMiles = distanceToPassanger * 0.000621371
        self.passangerName.text = "\(personName) is \(String(format: "%.1f", distanceMiles)) miles away"
        
        _ = Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(updateCountdown), userInfo: requestExpirationTime, repeats: false)
        
        self.view.bringSubview(toFront: self.pickupRequestView)
    }
    

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
    
    
    func changePickupRequestViewToNoResponce () {
        self.closeButton.isHidden = false
        self.passPassanger.isHidden = true
        self.acceptPassanger.isHidden = true
        self.passangerName.text = "Too Much Time Passed"
    }
    
    
    //driver and passanger method -method
    func displayDriverDrivingDirections (from fromLocation: CLLocationCoordinate2D, to toLocation: CLLocationCoordinate2D) {

    
        // remove the old route polygon
        removeRouteOverlays()
        
        
        // get directions to that person
        let drivingDirectionsRequest = MKDirectionsRequest()
        drivingDirectionsRequest.source = MKMapItem(placemark: MKPlacemark(coordinate: fromLocation))
        drivingDirectionsRequest.destination = MKMapItem.init(placemark: MKPlacemark(coordinate: toLocation))
        drivingDirectionsRequest.transportType = .automobile
        
        let drivingDirections = MKDirections(request: drivingDirectionsRequest)
        
        drivingDirections.calculate { (responce, error) in
            if error == nil {
                
                if let unwrappedResponce = responce {
                    
                    for route in unwrappedResponce.routes {
                     
                        self.mapView.add(route.polyline)
                        // todo this is zooming in too much
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
                        if self.userStatusMode == 1 { // is driver
                            self.updateDriverEnrouteInfo(route)
                        }
                    }
                }
                
            } else {
                print("error getting directions")
            }
        }
    }
    
    
    // driver - method
    func addPassangerPickupPin (_ passangerLocationForMap: CLLocationCoordinate2D) {
    
        let userLocation: passangerPickupLocationAnnotation = passangerPickupLocationAnnotation.init(passangerLocationForMap, "Pickup Location")
        mapView.addAnnotation(userLocation)
    }
    
    
    // driver - method
    
    func updateDriverEnrouteInfo (_ route: MKRoute) {
        let updatedTravelInfo = [
            "eta" : route.expectedTravelTime,
            "distance" : route.distance
        ]
        self.ref.child("trips").child(self.theTripDirectory).child("travelInfo").updateChildValues(updatedTravelInfo)
    }
    
    
    // driver -method
    func makeATrip (_ passangerRequestedLocation: NSDictionary, _ thePassangerID: String) {
    
        // make a new post in trip directory
        let thisAppUserID = UserDefaults.standard.object(forKey: kAppUserID) as! String

        let post = [
            "driverId" : thisAppUserID,
            "passangerId" : thePassangerID,
            "initialDistanceToPassanger" : "WhoKnows...",
            "status" : "driverEnroute",
            "timeStamp" : self.getCurrentTime(),
            "userStartingLocation" : passangerRequestedLocation
        ] as [String : Any]
        
        
        self.ref.child("trips").childByAutoId().updateChildValues(post, withCompletionBlock: { (error, reference) in
            // add the unique id of this trip to each of their user directories
            
            self.theTripDirectory = reference.key
            
            self.ref.child("users").child(thisAppUserID).child("trips").updateChildValues([reference.key : reference.key])
            self.ref.child("users").child(thePassangerID).child("trips").updateChildValues([reference.key : reference.key])
            
            
            let passangerLocationForMap: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: passangerRequestedLocation.object(forKey: kLatitude) as! CLLocationDegrees, longitude: passangerRequestedLocation.object(forKey: kLongitude) as! CLLocationDegrees)
            

            self.displayDriverDrivingDirections(from: self.currentLocation.coordinate, to: passangerLocationForMap)
            self.addPassangerPickupPin(passangerLocationForMap)
            self.updateDriverUIForEnroute()
            
        })
    }
    
    
    func updateDriverUIForEnroute () {
        
        self.addressLabel.text = "Follow the route to the Passanger."
        
        self.cancelButton.setTitle("Cancel Passanger Pickup", for: .normal)
        self.view.bringSubview(toFront: self.cancelButton)
        
        self.view.bringSubview(toFront: onTripButton)
        onTripButton.setTitle("Pickup Pasanger", for: .normal)
    }
    
    
    
    // displays driving directions for driver
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let renderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
        renderer.strokeColor = UIColor.blue
        renderer.lineWidth = 2.0
        return renderer
    }
    
    
    // driver method
    @IBAction func passUserRequestToAnotherDriver (_ sender: Any) {
        
        let thisAppUserID = UserDefaults.standard.object(forKey: kAppUserID) as! String
        ref.child("users").child(thisAppUserID).child("requests").child(pickupRequestUserUniqueID).updateChildValues([kStatus: kPassed])
        
        closeRequestView()
    }
    
    // driver method
    @IBAction func acceptPassangerRequest (_ sender: Any) {
        
        moveToEnrouteDriver()
        
        let thisAppUserID = UserDefaults.standard.object(forKey: kAppUserID) as! String
        ref.child("users").child(thisAppUserID).child("requests").child(pickupRequestUserUniqueID).updateChildValues([kStatus: kAccepted])
        
        // update the request in the main request directory
        ref.child("requests").child(requestDirectoryRequestID).updateChildValues([kStatus: kAccepted])

        closeRequestView()
    }
    

    @IBAction func closePassangerRequestView (_ sender: Any) {
        closeRequestView()
    }
    
    func closeRequestView () {
        self.view.sendSubview(toBack: self.pickupRequestView)
    }
    
    func ifLookingForPassangerThenStop () {
        
    // if user is in "driver" mode
        if userStatusMode == 1 {
            stopLookingForPassangers()
        }
    }
    
    // todo have the app, afterbign being close be able to resum status. eg  the drier is still enroute, or on a trip... this allows app switching
    
    func moveToEnrouteDriver ()  {
        
        stopLookingForPassangers()
        
        isEnroute = true
        
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("enrouteDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.setLocation(currentLocation, forKey: appUserID) 
    }
    
    
    func moveFromEnrouteDriverToActiveDriver () {
    
        isEnroute = false
        
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("enrouteDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.removeKey(appUserID)
        
        // this puts the driver back in active driver status
        updateDriverLocationInDatabase ()
    }
    
    
    func moveFromEnrouteDriverToDriverDriver () {
        isEnroute = false

        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("enrouteDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.removeKey(appUserID)
        
        updateDriverDrivingPassanger()
    }
    
    // todo change activeDriver to waitingDrivers?
    
    func moveFromDrivingDriver()  {
        
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("drivingDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.removeKey(appUserID)
    }
    
    
    func stopLookingForPassangers() {
        
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
    
    
    // mapview delegtes
    
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
    
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        if annotation is driverAnnotation {
        
            let driverAnnotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "driver")
            driverAnnotationView.image = UIImage(named: "car")
            return driverAnnotationView
            
        } else {
            return nil
        }
    }
    
    
    func onATrip () -> Bool {
    
        if theTripDirectory == nil {
            return false
        } else {
            return true
        }
    }
    
    func endATrip() {
        theTripDirectory = nil
    }
    
    
    func driverIsEnroute() -> Bool {
        return isEnroute
    }
    
    func updateAddressLabel(_ location: CLLocation) {
        
        if userStatusMode == 0 && activeRequestPath == nil {
        
            CLGeocoder().reverseGeocodeLocation(location) { (placemarks, error) in
                
                if error != nil {
                    print(error ?? "Unknown Error")
                } else {
                    
                    let placeMark: CLPlacemark!
                    placeMark = placemarks?[0]
                    
                    var addressString = ""
                    
                    if let locationName = placeMark.addressDictionary!["Name"] as? String {
                        addressString.append("\(locationName)\n")
                    }
                    if let street = placeMark.addressDictionary!["Thoroughfare"] as? String {
                        addressString.append("\(street)\n")
                    }
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
    
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let theLocaiton = locations.last!
        
        if theLocaiton.horizontalAccuracy < 100 {

            currentLocation = theLocaiton
            
             if zoomedToInitialLocation == false {
                
                let mapCenter = CLLocationCoordinate2D(latitude: currentLocation.coordinate.latitude, longitude: currentLocation.coordinate.longitude)
                
                let region = MKCoordinateRegion(center: mapCenter, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                mapView.setRegion(region, animated: true)
            
                zoomedToInitialLocation = true
                
                // update the label this time
                updateAddressLabel(currentLocation)
                
            } else {
            
                // if in driver mode, update the database with that person's locaiton
                
                if let mode = userStatusMode, mode == 1 {
                    
                    if onATrip() {
                    
                        if driverIsEnroute() {
                            updateEnrouteDriverPosition()
                        } else {
                            updateDriverDrivingPassanger()
                        }
                        
                    } else {
                    
                        updateDriverLocationInDatabase()
                    }

                }
            }
        }
    }
    
    func updateDriverLocationInDatabase () {
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("readyDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.setLocation(currentLocation, forKey: appUserID)
    }
    
    func updateEnrouteDriverPosition() {
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("enrouteDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.setLocation(currentLocation, forKey: appUserID)
    }
    
    func updateDriverDrivingPassanger() {
        let geoFire: GeoFire = GeoFire(firebaseRef: ref.child("drivingDrivers"))
        let appUserID: String = UserDefaults.standard.object(forKey: kAppUserID) as! String
        geoFire.setLocation(currentLocation, forKey: appUserID)
    }

    
    func getCurrentTime () -> String {
        
        let theDate = Date()
        let formatter = DateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale!
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        
        return formatter.string(from: theDate)
    }
    
    func getExpirationTime (addTime secondsToAdd: Double) -> String {
        
        var theDate = Date()
        let formatter = DateFormatter()
        formatter.locale = NSLocale(localeIdentifier: "en_US_POSIX") as Locale!
        formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
        
        theDate.addTimeInterval(secondsToAdd)

        return formatter.string(from: theDate)
    }
    
    
    // passanger method
    @IBAction func requestButtonPressed(_ sender: Any) {
        
        if self.driversAreNearBy() {
            
            driversThatPassed = [:] // reset this dictionary, as no dirvers have passed on this new request yet
            
            requestButton.isEnabled = false
            
            let attempToPostRequest =  ref.child("requests").childByAutoId()
            
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
            
            attempToPostRequest.updateChildValues(postDictionary, withCompletionBlock: { (error, requestReference) in
                
                if error == nil {
                    
                    self.activeRequestPath = requestReference
                    self.view.bringSubview(toFront: self.cancelButton)
                    
                    self.sendPickUpRequestToNearbyDrivers()

                } else { // error
                    self.requestButton.isEnabled = true
                    self.activeRequestPath = nil
                }
            })
            
            let userLocation: passangerPickupLocationAnnotation = passangerPickupLocationAnnotation.init(mapView.centerCoordinate, "Pickup Location")
            mapView.addAnnotation(userLocation)
            
            self.startListeningForDriversToAcceptPickupRequest()
            
  
        } else {
           showNoNearbyDriversGUIUpdate()
        }
    }
    
    /*
    func allDriversPassed() {
        
        activeRequestPath.updateChildValues(["status" : kNoAvailableDrivers], withCompletionBlock: { (error, ref) in
            
            if error == nil {
                self.activeRequestPath = nil
                self.view.bringSubview(toFront: self.requestButton)
                self.requestButton.isEnabled = true
                
                self.showNoNearbyDriversGUIUpdate()
            }
        })
    }
    */
    
    func showNoNearbyDriversGUIUpdate () {
        
        self.removePassangerPickupLocationAnnotation()
        
        let alert = UIAlertController(title: "Sorry", message: "There are no available drivers nearby.", preferredStyle: .alert)
        let closeButton = UIAlertAction(title: "Close", style: .destructive, handler: nil)
        alert.addAction(closeButton)
        self.present(alert, animated: true, completion: nil)
    }
    
    
    // todo reintroduce this thought the code for a cleaner experience
    
    func refThisUsersDirectory () -> FIRDatabaseReference {
        
        let thisAppUserID = UserDefaults.standard.object(forKey: kAppUserID) as! String
        return ref.child("users").child(thisAppUserID)
    }
    
    
    // passanger meathod
    func startListeningForDriversToAcceptPickupRequest () {
    
        refThisUsersDirectory().child("trips").observe(.childAdded, with: { (tripSnapshot) in
            
            let tripKey: String =  tripSnapshot.value as! String

            // todo it is so spupid beacus it calls this for each trip, even the old ones... perhps move trips into an "old trips" dir in the user dir
            
                  self.ref.child("trips").child(tripKey).observe(.value, with: { (fullTripDataSnapshot) in
                    
                    if let tripDictionary = fullTripDataSnapshot.value as? NSDictionary {
                        
                        if let status: String = tripDictionary.object(forKey: "status") as? String {
                        
                            if status == "driverEnroute" {
                                // show an alert that the driver is coming
                            
                                
                                if let shownAlert = tripDictionary.object(forKey: "alertedPassangerDriverEnroute") as? Bool, shownAlert == true  {
                                
                                } else {
                                    
                                    self.noResponceTimer.invalidate()
                                    
                                    self.ref.child("trips").child(tripKey).updateChildValues(["alertedPassangerDriverEnroute" : true])
                                    
                                    let driverID: String = tripDictionary.object(forKey: "driverId") as! String
                                    /*
                                    
                                    let newTripAlert = UIAlertController(title: "Driver Enroute", message: "With ID: \(driverID)", preferredStyle: .alert)
                                    
                                    let closeAction = UIAlertAction(title: "Ok", style: .default, handler: nil)
                                    newTripAlert.addAction(closeAction)
                                    
                                    self.present(newTripAlert, animated: true, completion: nil)
                                    */
                                    self.stopLookingForDrivers()
                                    
                                    self.showDriverOnMapEnrouteToPassanger(driverID, tripDictionary.object(forKey:"userStartingLocation") as! NSDictionary)
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
                            } else if status == kPickedUpPassanger {
                                
                                if let pickedUp = tripDictionary.object(forKey: "passangerDeviceHasBeenPickedUp") as? Bool, pickedUp == true  {
                                    
                                } else {
                                    
                                    self.ref.child("trips").child(tripKey).updateChildValues(["passangerDeviceHasBeenPickedUp" : true])
                                    
                                    if self.watchDriverForPickup != nil {
                                        self.ref.removeObserver(withHandle: self.watchDriverForPickup)
                                    }
                                    
                                    self.view.sendSubview(toBack: self.cancelButton)
                                    self.cancelButton.isEnabled = false
                                    
                                    // remvoe the enroute overlay but keep the pickup location pin
                                    self.removeRouteOverlays()
                                    
                                    self.view.sendSubview(toBack: self.requestButton)
                                    
                                    
                                    // set passanger UI for the trip
                                    self.addressLabel.text = "Enroute To Your Destination"
                                    
                                    
                                    // todo move requests to "old request" dir
                                    self.activeRequestPath = nil
                                    
                                    self.view.bringSubview(toFront: self.blankButton)
                                    
                                    // todo draw polygon of the route to the passanger destination
                                }
                                
                            } else if status == kPassangerDroppedOff {
                                
                                if let droppedOff = tripDictionary.object(forKey: "passangerDeviceHasBeenDroppedOff") as? Bool, droppedOff == true  {
                                    
                                } else {
                                    
                                    self.ref.child("trips").child(tripKey).updateChildValues(["passangerDeviceHasBeenDroppedOff" : true])

                                    
                                    // get them ready to take another trip

                                    self.startLookingForDrivers()
                                    
                                    let centerOfMap = CLLocation(latitude:self.mapView.centerCoordinate.latitude, longitude: self.mapView.centerCoordinate.longitude)

                                    self.updateAddressLabel(centerOfMap)
                                    
                                    self.requestButton.isEnabled = true
                                    self.view.bringSubview(toFront: self.requestButton)
                                    
                                    self.removeRouteGUI()
                                    
                                    // todo prompt the passanger to rate the driver
                                    
                                }
                            }
                        }
                    }
                })
        })
    }
    
    
    // passanger -method
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
    
    

    func driversAreNearBy () -> Bool {
    
        if nearbyDrivers.count > 0 {
            return true
        } else {
            return false
        }
    }
    
    func sendPickUpRequestToNearbyDrivers () {
    
        let thisAppUserID = UserDefaults.standard.object(forKey: kAppUserID) as! String
        
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
    
    
    // passanger method
    
    func startWaitingForDriverTimer(_ nearestDriverID: String, _ requestReference: String) {
    
        noResponceTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: false) { (Timer) in
            
            // too late to accept
            
            if self.activeRequestPath == nil {
            
            } else {
            
          //  self.activeRequestPath.updateChildValues(["status" : kNoResponce], withCompletionBlock: { (error, ref) in

                self.ref.child("users").child(nearestDriverID).child("requests").child(requestReference).updateChildValues([kStatus: kNoResponce], withCompletionBlock: { (error, ref) in
                    
                    // alert driver it is too late, once scuessfull then update the passanger
                    
                    self.driversThatPassed[nearestDriverID] = nearestDriverID
                    self.sendPickUpRequestToNearbyDrivers()
                    }
                )}
           // )}
        }
    }
    
    // passanger method
    func startListeningForIfDriverPassed (_ nearestDriverID: String, _ requestReference: String) {
        
        ref.child("users").child(nearestDriverID).child("requests").child(requestReference).child("status").observe(.value, with: { (snapshot) in
            
            if let status = snapshot.value as? String, status == kPassed {
                
                // add this driver id to the list of those who have passed this pickup
                self.driversThatPassed[nearestDriverID] = nearestDriverID
                self.sendPickUpRequestToNearbyDrivers()
            }
        })
    }
    
    
    func findNearestAvailableDriver() -> String {
    
        var closestDistance = Double.greatestFiniteMagnitude
        var closestDriverKey = kEveryonePassed
        
        for possibleDriver in nearbyDrivers {
            
            // has this driver already been asked, but decided to pass?
            if let _ = driversThatPassed[possibleDriver.key] {
                
                // this driver already passed up the opportunity to pick up this passanger
                
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
    
    
    func removePassangerPickupLocationAnnotation () {
        for annotation in mapView.annotations {
            if annotation is passangerPickupLocationAnnotation {
                mapView.removeAnnotation(annotation)
            }
        }
    }
    
    func removePassangerDestinationLocationAnnotation () {
        for annotation in mapView.annotations {
            if annotation is passangerDestinationLocationAnnotation {
                mapView.removeAnnotation(annotation)
            }
        }
    }
    
    func removeRouteGUI () {
        removePassangerPickupLocationAnnotation()
        removePassangerDestinationLocationAnnotation()
        removeRouteOverlays()
    }
    
    func cancelRide() {
        
        removeRouteGUI()
        
        if userStatusMode == 0 { // is passanger

        activeRequestPath.updateChildValues(["status" : kPassengerCancelled], withCompletionBlock: { (error, ref) in
            
            if error == nil {
                
                // update the driver request driectory
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
        // update the enoruteDriver to not inlcue me, put me back on ready drivers
        moveFromEnrouteDriverToActiveDriver()
        
        // cancel this in trips/theTripDirectory
        ref.child("trips").child(theTripDirectory).updateChildValues(["status" : canceller])
        // use and observer there to alert the passanger that the drive was canceled
        endATrip()
        
        // /requests/requestDriectoyRequestId  status to DriverCanceledEnroute
        ref.child("requests").child(requestDirectoryRequestID).updateChildValues(["status" : canceller])
        requestDirectoryRequestID = nil
        
        if canceller == kDriverCancelled {
         
            let thisAppUserID = UserDefaults.standard.object(forKey: kAppUserID) as! String
            
            // users/self/requests/pickuprequestuseridstring/status to DriverCanceledEnroute
            ref.child("users").child(thisAppUserID).child("requests").child(pickupRequestUserUniqueID).updateChildValues(["status" : kDriverCancelled])
            pickupRequestUserUniqueID = nil
           
        } else if canceller == kPassengerCancelled {
        
            showPassangerCancelledAlert()
            
        }
        
        
        //// update the UI
        
        if userStatusMode == 0 { // passanger
            let centerOfMap = CLLocation(latitude: pickupLocation[kLatitude]!, longitude: pickupLocation[kLongitude]!)
            updateAddressLabel(centerOfMap)
            
        } else { // driver
            addressLabel.text = ""
        }
        
        removeRouteGUI()
       
        // switch back to the looking for passangers button
        self.view.sendSubview(toBack: self.cancelButton)
        
        // re-center on the driver
        let centerOnUser = MKCoordinateRegion(center: currentLocation.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        
        mapView.setRegion(centerOnUser, animated: true)

    }
    
    
    func removeRouteOverlays () {
        for overlay in mapView.overlays {
            mapView.remove(overlay)
        }
    }
    
    
    func showPassangerCancelledAlert () {
    
        let alert = UIAlertController(title: "Passanger Cancelled", message: "Sorry, but the passanger cancelled", preferredStyle: .alert)
        let close = UIAlertAction(title: "Ok", style: .default, handler: nil)
        alert.addAction(close)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        cancelRide()
    }

    
  
    
    // todo finish writing me and also call me
    func pickupPassangerAndStartTheirTrip () {
        isEnroute = false
        
    }
    //todo add alert view asking if teh user or driver really wants to cancel the ride
    
    
    
    // driver method
    
    @IBAction func startDrivingWithPassanger () {
    
        //// update database
        
        // update location
        moveFromEnrouteDriverToDriverDriver()
        
        ref.child("trips").child(theTripDirectory).updateChildValues([kStatus : kPickedUpPassanger])
        
        // tell pannsager to do this, ad a listen for trip status
        
        // update the ui
        addressLabel.text = "Drive to final destination"
        
        self.removeRouteOverlays()
        
        // hide the pickup passanger button
        self.view.sendSubview(toBack: onTripButton)
        
        // show finish ride button
        self.view.bringSubview(toFront: completeTripButton)
        
        
        // todo navigate driver to user destination
        
    }
    
    
    // driver method
    @IBAction func completeTrip () {
        
        // update database
        ref.child("trips").child(theTripDirectory).updateChildValues([kStatus : kPassangerDroppedOff])
        
        endATrip()
        
        // update UI
        self.view.sendSubview(toBack: completeTripButton)
        self.view.bringSubview(toFront: requestButton)
        
        removeRouteGUI()
        
        self.addressLabel.text = ""
        
        // ask triver to mvoe back onto active list
        let alert = UIAlertController(title: "Another Drive?", message: "Start looking for another pickup?", preferredStyle: .alert)
        
        let moreDriving = UIAlertAction(title: "Another Pickup", style: .default, handler: { _ in
            self.startLookingForPassangers()
            self.updateDriverLocationInDatabase() // move driver back onto active list

        })
        
        let stopDriving = UIAlertAction(title: "No More Pickups", style: .destructive, handler: { _ in
            self.requestButton.setTitle("Not Looking For Passangers", for: .normal)
        })
        
        alert.addAction(moreDriving)
       // alert.addAction(stopDriving)
        
        self.present(alert, animated: true)
        
        // todo prompt driver to rate passanger
    }
    
    
    
    /*
     func showTutorial () {
     
     let storyboard = UIStoryboard.init(name: "Main", bundle: nil)
     _ = storyboard.instantiateViewController(withIdentifier: "tutorialNav")
     
     
     let initialViewController: UINavigationController = storyboard.instantiateViewController(withIdentifier: "tutorialNav") as! UINavigationController
     
     
     self.present(initialViewController, animated: true, completion: nil)
     }
     */
    
}

