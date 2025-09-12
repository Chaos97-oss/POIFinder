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
    @Published var errorMessage: String?   

    private let searchService = POISearchService()
    private let completerService = SearchCompleterService()
    private var cancellables = Set<AnyCancellable>()

    init() {
        completerService.$suggestions
            .receive(on: DispatchQueue.main)
            .assign(to: \.suggestions, on: self)
            .store(in: &cancellables)

        // Listen for completer errors if service publishes them
        completerService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                if let msg = msg { self?.errorMessage = msg }
            }
            .store(in: &cancellables)

        fetchFavoritesFromStorage()
    }

    func searchPOIs(query: String, near coordinate: CLLocationCoordinate2D) {
        searchService.search(query: query, near: coordinate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let results):
                    if results.isEmpty {
                        self?.errorMessage = "No results found for '\(query)'"
                    } else {
                        self?.pois = results
                    }
                case .failure(let error):
                    self?.errorMessage = "Search failed: \(error.localizedDescription)"
                }
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
