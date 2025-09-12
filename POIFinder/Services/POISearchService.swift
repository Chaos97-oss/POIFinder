//
//  POISearchService.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import Foundation
import MapKit

class POISearchService {
    func search(query: String,
                near coordinate: CLLocationCoordinate2D,
                completion: @escaping (Result<[POI], Error>) -> Void) {
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let mapItems = response?.mapItems else {
                completion(.success([]))      
                return
            }

            let pois = mapItems.compactMap { item -> POI? in
                guard let name = item.name else { return nil }
                return POI(
                    name: name,
                    category: item.pointOfInterestCategory?.rawValue ?? "Uncategorized",
                    address: item.placemark.title ?? "No address",
                    coordinate: item.placemark.coordinate
                )
            }

            completion(.success(pois))
        }
    }
}
