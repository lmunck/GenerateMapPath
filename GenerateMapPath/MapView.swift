//
//  MapView.swift
//  GenerateMapPath
//
//  Created by Anders Munck on 20/03/2021.
//

import MapKit
import SwiftUI

// MARK: MapView

struct MapView: UIViewRepresentable {
    
    //typealias UIViewType = MKMapView
    @State var locationManager = LocationManager()
    
    // Input
    @Binding var routePlan: RoutePlan?
    
    // Output
    @Binding var mapRegion:MKCoordinateRegion
    @Binding var mapHeading:Double
    @Binding var mapLockedToUser:Bool
    
    
    // MapView Functions
    func makeCoordinator() -> MapViewCoordinator {
        return MapViewCoordinator(self)
    }
    
    func makeUIView(context: Context) -> MKMapView {
        
        // Setup delegate
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        // Register custom annotation views
        mapView.register(MKMarkerAnnotationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(StopAnnotation.self))
        mapView.register(MKUserLocationView.self, forAnnotationViewWithReuseIdentifier: NSStringFromClass(MKUserLocation.self))
        
        mapView.showsScale = true
        mapView.showsCompass = false
        
        // Get user location
        locationManager.start()
        
        // Show user location
        mapView.showsUserLocation = true
        
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        
        updateAnnotationsAndPolylines(mapView)
        checkIfMapLockedToUser(mapView)
        
    }
    
    // Check if any annotations changed, and update those that did
    private func updateAnnotationsAndPolylines(_ mapView: MKMapView) {
        
        // If stop annotations are updated, add them
        if let stopAnnotations = routePlan?.stopAnnotations {
            
            // If number of annotations changed, then it's definitely time to redraw
            if stopAnnotations.count != mapView.annotations.count - (mapView.showsUserLocation ? 1 : 0) {
                
                mapView.removeAnnotations(mapView.annotations)
                mapView.addAnnotations(stopAnnotations)
                
            } else {
                
                // Check if any StopAnnotations have moved
                for mapAnnotation in mapView.annotations {
                    
                    // Find a StopAnnotation
                    if let mapAnnotation = mapAnnotation as? StopAnnotation {
                        
                        // Find the same StopAnnotation in the data
                        if let index = stopAnnotations.firstIndex(where: { $0.title == mapAnnotation.title }) {
                            
                            let stopAnnotation = stopAnnotations[index]
                            
                            // If data changed, update mapAnnotations
                            if mapAnnotation.coordinate.latitude != stopAnnotation.coordinate.latitude || mapAnnotation.coordinate.longitude != stopAnnotation.coordinate.longitude {
                                    
                                mapView.removeAnnotation(mapAnnotation)
                                mapView.addAnnotation(stopAnnotation)
                                
                            }
                        }
                    }
                }
            }
        } else {
            
            // No stop annotations, so remove all
            mapView.removeAnnotations(mapView.annotations)
            mapView.removeOverlays(mapView.overlays)
            
        }
        
        
        // Add polylines
        if let polyLines = routePlan?.stopPolyline {
            mapView.removeOverlays(mapView.overlays)
            mapView.addOverlay(polyLines)
        }
    }
    
    // Check if map locked to user and change map settings accordingly
    private func checkIfMapLockedToUser(_ mapView: MKMapView) {
        
        if mapLockedToUser && mapView.userTrackingMode != .followWithHeading {
            
            let noLocation = CLLocationCoordinate2D()
            let viewRegion = MKCoordinateRegion(center: noLocation, latitudinalMeters: 200, longitudinalMeters: 200)
            mapView.setRegion(viewRegion, animated: false)
            
            mapView.setUserTrackingMode(.followWithHeading, animated: true)
            
            
        } else if !mapLockedToUser && mapView.userTrackingMode != .none {
            mapView.setUserTrackingMode(.none, animated: true)
            mapView.showsUserLocation = false
        }
    }
    
    // MARK: Coordinator
    class MapViewCoordinator: NSObject, MKMapViewDelegate {
        
        var parent: MapView
        
        init(_ parent: MapView) {
            self.parent = parent
        }
        
        // MARK: LOGIC
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
             
                parent.mapRegion = mapView.region
                parent.mapHeading = mapView.camera.heading
             
        }
        
        // MARK: FORMATTING
        
        // Polyline formatting
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 5
            return renderer
        }
        
        // Annotation formatting
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            
            
            let identifier = NSStringFromClass(StopAnnotation.self)
            
            var annotationView: MKAnnotationView?
            
            if let annotation = annotation as? StopAnnotation {
                
                let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view.markerTintColor = UIColor.darkGray
                view.glyphText = annotation.title ?? ""
                view.glyphTintColor = UIColor.white
                view.titleVisibility = .hidden
                view.zPriority = .min
                view.isDraggable = true
                view.canShowCallout = true // Expect to use call out for deleting annotation
                annotationView = view
                
            }
            
            return annotationView
            
        }
        
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
            if view is MKUserLocationView {
                
                // User selected user-annotation
                
            }
            
            if view is MKMarkerAnnotationView {
                // User selected stop annotation
            }
        }
        
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
            
                // User dragged a marker, update Coordinates
        }
    }
    
}

// Annotation View

class UserAnnotationViewContainer: MKAnnotationView {
    private let annotationFrame = CGRect(x: 0, y: 0, width: 40, height: 40)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.frame = annotationFrame
        centerOffset = CGPoint(x: 0, y: -frame.size.height / 2)
        self.backgroundColor = .clear
        
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented!")
    }

    public var number: Int = 0 {
        didSet {
            _setup(number: number)
        }
    }

    func _setup(number: Int) {
        backgroundColor = .clear
        
        let vc = UIHostingController(rootView: UserAnnotationView())
        if let view = vc.view {
            view.backgroundColor = .clear
            addSubview(view)
            view.frame = bounds
        }
       
    }
}

struct UserAnnotationView: View {
    
    
    var body: some View {
        ZStack {
            
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .scaledToFit()
            
        }
        .frame(width: 40, height: 40, alignment: .bottom)
    }
}


// MARK: MapCalloutView


/**
A custom callout view to be be passed as an MKMarkerAnnotationView, where you can use a SwiftUI View as it's base.
*/
class MapCalloutView: UIView {
    
    //create the UIHostingController we need. For now just adding a generic UI
    let body:UIHostingController<AnyView> = UIHostingController(rootView: AnyView(Text("Hello")) )

    
    /**
    An initializer for the callout. You must pass it in your SwiftUI view as the rootView property, wrapped with AnyView. e.g.
    MapCalloutView(rootView: AnyView(YourCustomView))
    
    Obviously you can pass in any properties to your custom view.
    */
    init(rootView: AnyView) {
        super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        body.rootView = AnyView(rootView)
        setupView()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupView()
    }
    
    /**
    Ensures the callout bubble resizes according to the size of the SwiftUI view that's passed in.
    */
    private func setupView() {
        
        translatesAutoresizingMaskIntoConstraints = false
        
        //pass in your SwiftUI View as the rootView to the body UIHostingController
        //body.rootView = Text("Hello World * 2")
        body.view.translatesAutoresizingMaskIntoConstraints = false
        body.view.frame = bounds
        body.view.backgroundColor = nil
        //add the subview to the map callout
        addSubview(body.view)

        NSLayoutConstraint.activate([
            body.view.topAnchor.constraint(equalTo: topAnchor),
            body.view.bottomAnchor.constraint(equalTo: bottomAnchor),
            body.view.leftAnchor.constraint(equalTo: leftAnchor),
            body.view.rightAnchor.constraint(equalTo: rightAnchor)
        ])
        
        sizeToFit()
        
    }
}
