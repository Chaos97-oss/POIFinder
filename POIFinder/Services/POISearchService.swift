//
//  POISearchService.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import Foundation
import MapKit

class POISearchService {
    func search(query: String, near coordinate: CLLocationCoordinate2D, completion: @escaping ([POI]) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 5000, longitudinalMeters: 5000)

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                print("Search error:", error)
                completion([])
                return
            }

            guard let response = response else {
                print("Search response is nil")
                completion([])
                return
            }

             let items = response.mapItems
             guard !items.isEmpty else {
                print("No map items found in region:", request.region)
                completion([])
                return
            }

            
            let pois = items.compactMap { item -> POI? in
                guard let name = item.name, let location = item.placemark.location else { return nil }
                return POI(
                    name: name,
                    category: item.pointOfInterestCategory?.rawValue ?? "Unknown",
                    address: item.placemark.title ?? "",
                    coordinate: location.coordinate
                )
            }
            print("POIs found:", pois.map { $0.name })
            completion(pois)
        }
    }
}
