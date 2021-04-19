//
//  LocationManager.swift
//  GenerateMapPath
//
//  Created by Anders Munck on 20/03/2021.
//

import CoreLocation

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    
    let manager = CLLocationManager()
    
    @Published var userLocation:CLLocationCoordinate2D?
    @Published var userHeading:Double = 0
    
    override init() {
        super.init()
        manager.delegate = self
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }
    
    func stop() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first?.coordinate {
            userLocation = location
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.magneticHeading
        userHeading = heading
    }
}
