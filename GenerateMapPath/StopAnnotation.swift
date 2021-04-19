//
//  QualkStopAnnotation.swift
//  GenerateMapPath
//
//  Created by Anders Munck on 28/03/2021.
//

import Foundation
import MapKit

class StopAnnotation: MKPointAnnotation, Codable, Identifiable {
    
    // Info
    //@DocumentID var id:String?
    var id:String?
    var orderIndex:Int? // For sorting
    
    enum CodingKeys: CodingKey {
        case title, subtitle, latitude, longitude, orderIndex, id
    }

    override init() {
        super.init()
    }

    public required init(from decoder: Decoder) throws {
        super.init()

        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        orderIndex = try container.decode(Int.self, forKey: .orderIndex)

        let latitude = try container.decode(CLLocationDegrees.self, forKey: .latitude)
        let longitude = try container.decode(CLLocationDegrees.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(subtitle, forKey: .subtitle)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(orderIndex, forKey: .orderIndex)
    }
}

extension StopAnnotation {
    
    static var example: StopAnnotation {
        let annotation = StopAnnotation()
        annotation.title = "Testlocation"
        annotation.subtitle = "Home to the 2012 Summer Olympics."
        annotation.coordinate = CLLocationCoordinate2D(latitude: 55.670660, longitude: 12.535274)
        annotation.orderIndex = 1
        return annotation
    }
    
    static var exampleArray: [StopAnnotation] {
        var annotations:[StopAnnotation] = []
        let coordinates:[CLLocationCoordinate2D] = [
            CLLocationCoordinate2D(latitude: 55.670616, longitude: 12.535209),
            CLLocationCoordinate2D(latitude: 55.670986, longitude: 12.535339),
            CLLocationCoordinate2D(latitude: 55.671416, longitude: 12.535474),
            CLLocationCoordinate2D(latitude: 55.671989, longitude: 12.535639),
            CLLocationCoordinate2D(latitude: 55.672745, longitude: 12.535889),
            CLLocationCoordinate2D(latitude: 55.673689, longitude: 12.536189)
        ]
        
        for (index, coordinate) in coordinates.enumerated() {
            let annotation = StopAnnotation()
            annotation.coordinate = coordinate
            annotation.orderIndex = index + 1
            annotations.append(annotation)
        }
        
        return annotations
        
    }
}

extension MKPointAnnotation: ObservableObject {
    public var wrappedTitle: String {
        get {
            self.title ?? ""
        }

        set {
            title = newValue
        }
    }

    public var wrappedSubtitle: String {
        get {
            self.subtitle ?? ""
        }

        set {
            subtitle = newValue
        }
    }
}
