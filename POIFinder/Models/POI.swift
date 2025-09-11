//
//  POI.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import Foundation
import CoreLocation

struct POI: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let category: String
    let address: String
    let coordinate: CLLocationCoordinate2D
    
    static func == (lhs: POI, rhs: POI) -> Bool {
            lhs.id == rhs.id
        }
}
