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

    private let searchService = POISearchService()
    private let persistenceService = PersistenceService()

    func searchPOIs(query: String, near coordinate: CLLocationCoordinate2D) {
        searchService.search(query: query, near: coordinate) { [weak self] results in
            DispatchQueue.main.async {
                self?.pois = results
                print("POIs found:", results.map { $0.name })
            }
        }
    }

    func saveFavorite(_ poi: POI) {
        persistenceService.save(poi: poi)
    }

    func fetchFavorites() -> [POI] {
        persistenceService.fetchFavorites()
    }
    
    @Published var suggestions: [MKLocalSearchCompletion] = []
    private let completerService = SearchCompleterService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        completerService.$suggestions
            .receive(on: DispatchQueue.main)
            .assign(to: \.suggestions, on: self)
            .store(in: &cancellables)
    }

    func updateSearchQuery(_ query: String) {
        completerService.updateQuery(query)
    }

}
