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
    @Published var favorites: [POI] = []

    private let searchService = POISearchService()
    private let completerService = SearchCompleterService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        completerService.$suggestions
            .receive(on: DispatchQueue.main)
            .assign(to: \.suggestions, on: self)
            .store(in: &cancellables)
        
        fetchFavoritesFromStorage()
    }

    func searchPOIs(query: String, near coordinate: CLLocationCoordinate2D) {
        searchService.search(query: query, near: coordinate) { [weak self] results in
            DispatchQueue.main.async {
                self?.pois = results
            }
        }
    }

    func saveFavorite(_ poi: POI) {
        PersistenceService.shared.save(poi: poi)
        fetchFavoritesFromStorage()
    }

    func fetchFavorites() -> [POI] {
        return favorites
    }

    private func fetchFavoritesFromStorage() {
        favorites = PersistenceService.shared.fetchFavorites()
    }

    func deleteFavorite(_ poi: POI) {
        PersistenceService.shared.delete(poi: poi)
        fetchFavoritesFromStorage()
    }

    func updateSearchQuery(_ query: String) {
        completerService.updateQuery(query)
    }
}
