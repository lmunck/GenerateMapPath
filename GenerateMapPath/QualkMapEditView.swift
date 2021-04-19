//
//  QualkMapEditView.swift
//  GenerateMapPath
//
//  Created by Anders Munck on 28/03/2021.
//

import SwiftUI
import MapKit


struct QualkMapEditView: View {
    
    // View state
    @State private var showDirections = false
    
    @StateObject var location = LocationManager()
    
    // User location
    
    // RoutePlanner
    let routePlanner = RoutePlanner()
    @State var routePlan:RoutePlan?
    @State var error:Error?
    @State private var findingRoute:Bool = false
    
    // Map input
    @State var mapLockedToUser:Bool = true
    @State var hideAnnotations:Bool = false
    
    // Map output
    @State var mapRegion:MKCoordinateRegion = MKCoordinateRegion()
    @State var mapHeading:Double = 0
    
    
    
    var body: some View {
        ZStack {
                    
            MapView(
                routePlan: $routePlan,
                mapRegion: $mapRegion,
                mapHeading: $mapHeading,
                mapLockedToUser: $mapLockedToUser
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            
            VStack {
                
                Spacer()
                
                //RoutePlannerStats(routePlan: routePlan, error: error)
                
                // Buttons
                HStack {
                    
                    // Auto generate Route button
                    Label("Auto", systemImage: findingRoute ? "wand.and.stars" : "wand.and.stars.inverse")
                        .onTapGesture {
                            
                            // Busy finding route
                            self.findingRoute = true
                            
                            // Aute generate route with 10 stops
                            routePlanner.getRoute(region: mapRegion, heading: Angle(degrees: mapHeading), stops: 10) { result in
                                switch result {
                                case .failure(let error):
                                    self.findingRoute = false
                                    self.error = error
                                case .success(let routePlan):
                                    self.findingRoute = false
                                    self.routePlan = routePlan
                                }
                            }
                        }
                    
                    // Mapped locked to user button
                    Label("Track", systemImage: mapLockedToUser ? "location.fill" : "location.slash.fill")
                        .onTapGesture {
                            routePlan = nil
                            mapLockedToUser.toggle()
                        }
                    
                    
                }
                .labelStyle(VerticalLabelStyle())
                .disabled(findingRoute)
                .padding()
                .background(Color.white.opacity(0.8))
                
            }
            
            if !mapLockedToUser {
                
                ZStack {
                    
                    Image(systemName: "mappin")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .offset(x: 0, y: -20)
                    
                    Text("Add stop")
                        .font(.headline)
                        .offset(y: 20)
                    
                }
                .onTapGesture {
                    
                    print("\(routePlan?.stopAnnotations.count ?? 0)")
                    
                    // Create annotation
                    let stopAnnotation = StopAnnotation()
                    stopAnnotation.orderIndex = (routePlan?.stopAnnotations.count ?? 0) + 1
                    stopAnnotation.coordinate = mapRegion.center
                    stopAnnotation.title = "\((routePlan?.stopAnnotations.count ?? 0) + 1)"
                    
                    if routePlan != nil {
                        
                        // Plan exists, so append annotation
                        routePlan?.stopAnnotations.append(stopAnnotation)
                        print("Add annotation \(stopAnnotation.title ?? "")")
                        
                    } else {
                        
                        // No plan, so create one with annotation
                        let plan = RoutePlan(title: "ff", stepDirections: [], stepAnnotations: [], stepPolylines: [], stopAnnotations: [stopAnnotation], corners: [], estDistance: 0, estTime: 0)
                        
                        routePlan = plan
                        
                    }
                }
            }
            
        }
        .onAppear(perform: { location.start() })
        .onDisappear(perform: { location.stop() })
        
    }
}




struct QualkMapEditView_Previews: PreviewProvider {
    static var previews: some View {
        QualkMapEditView()
    }
}

// MARK: Label style
struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .center, spacing: 2) {
            configuration.icon
                .scaleEffect(2)
                .frame(width: 40, height: 40, alignment: .center)
            configuration.title.font(.footnote)
        }
        .frame(width: 60, height: 60)
    }
}

// MARK: Sub views

struct RoutePlannerStats: View {
    
    let routePlan:RoutePlan?
    let error:Error?
    
    @State private var showDirections:Bool = false
    
    var body: some View {
        if let plan = routePlan {
            
            VStack {
                Text("Name: \(plan.title)")
                Text("Distance: \(plan.estDistance, specifier: "%.0f")m")
                Text("Expected Travel time: \(plan.estTime, specifier: "%.0f")s")
                Text("Stops: \(plan.stopAnnotations.count)")
                
                Button(action: {
                    self.showDirections.toggle()
                }, label: {
                    Text("Show directions")
                })
            }
            .padding()
            .sheet(isPresented: $showDirections, content: {
                
                VStack(spacing: 0) {
                    Text("Directions")
                        .font(.largeTitle)
                        .bold()
                        .padding()
                    
                    Divider().background(Color.blue)
                    
                    List(0..<plan.stepDirections.count, id: \.self) { i in
                        Text(plan.stepDirections[i]).padding()
                    }
                }
            })
            
        } else {
            
            if let error = error {
                Text("\(error.localizedDescription)")
            }
            
        }
    }
}
