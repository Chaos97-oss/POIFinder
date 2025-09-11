//
//  MapViewModel.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import Foundation
import MapKit
import Combine

class MapViewModel: ObservableObject {
    @Published var pois: [POI] = []
    @Published var selectedPOI: POI?
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let searchService = POISearchService()
    private let completerService = SearchCompleterService()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        
        completerService.$suggestions
            .receive(on: DispatchQueue.main)
            .assign(to: \.suggestions, on: self)
            .store(in: &cancellables)
    }

    
    func searchPOIs(query: String, near coordinate: CLLocationCoordinate2D) {
        searchService.search(query: query, near: coordinate) { [weak self] results in
            DispatchQueue.main.async {
                self?.pois = results
                print("POIs found:", results.map { $0.name })
            }
        }
        
    }

    
    func saveFavorite(_ poi: POI) {
        PersistenceService.shared.save(poi: poi)
    }

    
    func fetchFavorites() -> [POI] {
        return PersistenceService.shared.fetchFavorites()
    }

    
    func updateSearchQuery(_ query: String) {
        completerService.updateQuery(query)
    }
}
