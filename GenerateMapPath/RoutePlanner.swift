//
//  RoutePlanner.swift
//  GenerateMapPath
//
//  Created by Anders Munck on 20/03/2021.
//

import MapKit
import SwiftUI


struct RoutePlan: Equatable {
    
    let title:String
    let stepDirections:[String]
    let stepAnnotations:[StopAnnotation]
    let stepPolylines:[MKPolyline]
    var stopAnnotations:[StopAnnotation] // These are ones shown on map
    var stopPolyline:MKPolyline { get { return getStopPolyline() }} // These should be auto-generated based on stopAnnotations
    let corners:[MKPointAnnotation]
    let estDistance:Double
    let estTime:Double
    
    private func getStopPolyline() -> MKPolyline {
        
        var locations:[CLLocationCoordinate2D] = []
        
        for annotation in stopAnnotations {
            locations.append(annotation.coordinate)
        }
        
        let stopPolylines = MKPolyline(coordinates: locations, count: locations.count)
        
        return stopPolylines
    }
    
}

// Generates a RoutePlan for a Qualk with a specific number of stops, based on user location, heading, and the size of the mapRegion

class RoutePlanner {
    
    func getRoute(region: MKCoordinateRegion, heading: Angle, stops:Int, completion: @escaping (Result<RoutePlan, Error>) -> Void) {
        
        // Get three other points of square
        let corners = getRouteCorners(region: region, heading: heading, spread: Angle(degrees: 90))
        
        // Get first leg
        self.getRouteLeg(start: region.center, finish: corners.0) { result in
            switch result {
            case .success(let routeLeg1):
                
                // Get second leg
                self.getRouteLeg(start: corners.0, finish: corners.1) { result in
                    switch result {
                    case .success(let routeLeg2):
                        
                        // Get third leg
                        self.getRouteLeg(start: corners.1, finish: corners.2) { result in
                            switch result {
                            case .success(let routeLeg3):
                                
                                // Get fourth leg
                                self.getRouteLeg(start: corners.2, finish: region.center) { result in
                                    switch result {
                                    case .success(let routeLeg4):
                                        
                                        let routePlan = self.createRoutePlan(
                                            route: (routeLeg1, routeLeg2, routeLeg3, routeLeg4),
                                            corners: (region.center, corners.0, corners.1, corners.2),
                                            stops: stops
                                            )
                                        
                                        completion(.success(routePlan))
                                        
                                    case .failure(let error):
                                        completion(.failure(error))
                                    }
                                }
                                
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
        
    }
    
    // Get four points to calculate walking routes between
    private func getRouteCorners(region: MKCoordinateRegion, heading: Angle, spread: Angle) -> (CLLocationCoordinate2D, CLLocationCoordinate2D, CLLocationCoordinate2D) {
        
        // Calculate three points in front of fthe user
        // The points form a paralellogram with the user at the corner:
        
        // start - the location of the user
        // heading - the direction the user is facing
        // spread - the angle of the corner where the user is standing
        // distance - the distance from the user to the Left and Right point
        
        // Get ratios
        let ratios = getLatLonRatio(region: region)
        let latRatio = ratios.0 // 0 = latLonRatio = difference in meters between 1 degree Lat vs 1 degree Lon at current location
        let distRatio = ratios.1 // 1 = distance ratio = 1 degree / meters
        
        // Turn heading 90 degrees (not sure why, but too lzy to find bug
        let heading = Angle(degrees: heading.degrees + 90)
        
        // Distance from start to mid point
        let diagonal:Double = distRatio * cos(Double(spread.radians / 2)) * 2
        
        // Left point
        let point1 = CLLocationCoordinate2D(
            latitude: region.center.latitude + distRatio * latRatio * sin(Double(heading.radians - spread.radians / 2)),
            longitude: region.center.longitude - distRatio * 1 * cos(Double(heading.radians - spread.radians / 2))
        )
        
        // Mid point
        let point2 = CLLocationCoordinate2D(
            latitude: region.center.latitude + diagonal * latRatio * sin(Double(heading.radians)),
            longitude: region.center.longitude - diagonal * 1 * cos(Double(heading.radians))
        )
        
        // Right point
        let point3 = CLLocationCoordinate2D(
            latitude: region.center.latitude + distRatio * latRatio * sin(Double(heading.radians + spread.radians / 2)),
            longitude: region.center.longitude - distRatio * 1 * cos(Double(heading.radians + spread.radians / 2))
        )
        
        return (point1, point2, point3)
        
    }
    
    // Get ratio between latitude and longitude + distance in meters of 1 degree at this location on Earth sphere
    private func getLatLonRatio(region: MKCoordinateRegion) -> (Double, Double) {
        
        // The distance in meters of one degree Latitude and one degree Longitude varies depending on how far North you are
        // To ensure the route is not oblong, I therefore have to compensate for the difference
        
        let start = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        let latDelta = CLLocation(latitude: start.coordinate.latitude + 1, longitude: start.coordinate.longitude)
        let lonDelta = CLLocation(latitude: start.coordinate.latitude, longitude: start.coordinate.longitude + 1)
        
        let oneDegreeLatInMeters = start.distance(from: latDelta)
        let oneDegreeLonInMeters = start.distance(from: lonDelta)
        
        let distance = region.span.latitudeDelta * oneDegreeLatInMeters / 4
        
        let latRatio = oneDegreeLonInMeters / oneDegreeLatInMeters
        let distRatio = distance / oneDegreeLonInMeters
        
        return (latRatio, distRatio)
    }
    
    
    
    // Calculate walking route between two points
    private func getRouteLeg(start: CLLocationCoordinate2D, finish: CLLocationCoordinate2D, completion: @escaping (Result<MKRoute, Error>) -> Void) {
        
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: finish))
        request.transportType = .walking
        
        let directions = MKDirections(request: request)
        
        directions.calculate { response,error in
            
            if let error = error {
                
                // No route found
                completion(.failure(error))
                
            } else if let route = response?.routes.first {
                
                completion(.success(route))
            }
            
        }
        
    }
    
    // Consolidate the four walking routes into one routePlan
    private func createRoutePlan(route: (MKRoute, MKRoute, MKRoute, MKRoute), corners:(CLLocationCoordinate2D, CLLocationCoordinate2D, CLLocationCoordinate2D, CLLocationCoordinate2D), stops:Int) -> RoutePlan {
        
        // Consolidate the simple things
        let title = route.1.name
        let estDistance = route.0.distance + route.1.distance + route.2.distance + route.3.distance
        let estTime = route.0.expectedTravelTime + route.1.expectedTravelTime + route.2.expectedTravelTime + route.3.expectedTravelTime
        let polyLines = [route.0.polyline, route.1.polyline, route.2.polyline, route.3.polyline]
        
        // Consolidate polyline coordinates into StopAnnotations
        var polylineCoordinates:[CLLocationCoordinate2D] = route.0.polyline.coordinates + route.1.polyline.coordinates + route.2.polyline.coordinates + route.3.polyline.coordinates
        
        // Remove unnecessary stops
        polylineCoordinates = trimCoordinates(coordinates: polylineCoordinates, stops: stops)
        
        /// Convert into StopAnnotations
        var stops:[StopAnnotation] = []
        var n = 1
        
        for coordinate in polylineCoordinates {
            let annotation = StopAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "\(n)"
            n += 1
            stops.append(annotation)
            
        }
        
        // Consolidate route steps into StopAnnotations
        var steps1:[MKRoute.Step] = route.0.steps
        steps1.removeLast() // Remove last step to avoid duplicate of first step in next leg
        var steps2 = route.1.steps
        steps2.removeLast() // Remove last step to avoid duplicate of first step in next leg
        var steps3 = route.2.steps
        steps3.removeLast() // Remove last step to avoid duplicate of first step in next leg
        let steps4 = route.3.steps
        
        let allSteps:[MKRoute.Step] = steps1 + steps2 + steps3 + steps4
        
        
        /// Convert to StopAnnotations
        let annotations:[StopAnnotation] = allSteps.map {
            let annotation = StopAnnotation()
            annotation.coordinate = $0.polyline.coordinate
            return annotation
        }
        
        for n in (0...annotations.count-1) {
            annotations[n].title = "\(n+1)"
            annotations[n].orderIndex = n
        }
        
        // Consolidate instructions
        let directions = allSteps.map { $0.instructions }.filter { !$0.isEmpty }
        
        // Consolidate corners
        let corner1 = MKPointAnnotation()
        corner1.coordinate = corners.0
        corner1.title = "A"
        let corner2 = MKPointAnnotation()
        corner2.coordinate = corners.1
        corner2.title = "B"
        let corner3 = MKPointAnnotation()
        corner3.coordinate = corners.2
        corner3.title = "C"
        let corner4 = MKPointAnnotation()
        corner4.coordinate = corners.3
        corner4.title = "D"
        
        let allCorners = [corner1, corner2, corner3, corner4]
        
        // Make RoutePlan
        let routePlan = RoutePlan(
            title: title,
            stepDirections: directions,
            stepAnnotations: annotations,
            stepPolylines: polyLines,
            stopAnnotations: stops,
            corners: allCorners,
            estDistance: estDistance,
            estTime: estTime
        )
        
        return routePlan
    }
    
    private func trimCoordinates(coordinates: [CLLocationCoordinate2D], stops: Int) -> [CLLocationCoordinate2D] {
        
        // Make array vars to store results in
        var returnCoordinates:[CLLocationCoordinate2D] = []
        var tempCoordinates = coordinates
        
        // If more Stops required than we have coordinates, just return original coordinate array
        if stops > tempCoordinates.count {
            
            returnCoordinates = tempCoordinates
            
        } else if stops > 0 {
            
            // Keep last coordinate no maqtter what
            let last:CLLocationCoordinate2D = tempCoordinates.removeLast()
            
            // If we have any remaining stops, distribute them evenly
            let remainingStops = stops - 1
            var middle:[CLLocationCoordinate2D] = []
            
            if remainingStops > 0 {
                
                let stopSize:Double = Double(tempCoordinates.count) / Double(remainingStops)
                
                for n in (0...remainingStops-1) {
                    
                    let index = Int(Double(Double(n) * stopSize))
                    middle.append(tempCoordinates[index])
                    
                }
                
            }
            
            returnCoordinates = middle + [last]
            
        }

        return returnCoordinates
    }
    
}


// Extension to get points from a polyline
public extension MKMultiPoint {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid,
                                              count: pointCount)

        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))

        return coords
    }
}

// Given a MKRoute, you can just do:
// route.polyline.coordinates



