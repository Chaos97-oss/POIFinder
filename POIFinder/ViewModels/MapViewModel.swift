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
    // MARK: - Published Properties
    @Published var pois: [POI] = []
    @Published var selectedPOI: POI?
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var favorites: [POI] = []
    @Published var recentSearches: [POI] = []
    @Published var currentRoute: MKRoute?
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var mapType: MKMapType = .standard
    @Published var errorMessage: String?

    // MARK: - Services
    private let searchService = POISearchService()
    private let completerService = SearchCompleterService()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization
    init() {
        bindCompleter()
        fetchFavoritesFromStorage()
    }

    // MARK: - Bind Autocomplete Suggestions
    private func bindCompleter() {
        completerService.$suggestions
            .receive(on: DispatchQueue.main)
            .assign(to: \.suggestions, on: self)
            .store(in: &cancellables)

        completerService.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in
                if let msg = msg { self?.errorMessage = msg }
            }
            .store(in: &cancellables)
    }

    // MARK: - Search POIs
    func searchPOIs(query: String, near coordinate: CLLocationCoordinate2D, completion: ((POI) -> Void)? = nil) {
        searchService.search(query: query, near: coordinate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let results):
                    self?.pois = results
                    if results.isEmpty {
                        self?.errorMessage = "No results found for '\(query)'"
                    } else {
                        completion?(results.first!)
                    }
                case .failure(let error):
                    self?.errorMessage = "Search failed: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Recent Searches
    func addToRecentSearches(_ poi: POI) {
        // Remove duplicates & insert at top
        recentSearches.removeAll { $0.id == poi.id }
        recentSearches.insert(poi, at: 0)
        // Limit recent searches to 5
        if recentSearches.count > 5 {
            recentSearches = Array(recentSearches.prefix(5))
        }
    }

    // MARK: - Update Notes
    func updateNote(for poi: POI, note: String) {
        if let index = pois.firstIndex(where: { $0.id == poi.id }) { pois[index].note = note }
        if let index = favorites.firstIndex(where: { $0.id == poi.id }) { favorites[index].note = note }
    }

    // MARK: - Directions
    func getDirections(to destination: CLLocationCoordinate2D, from source: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        MKDirections(request: request).calculate { [weak self] response, error in
            guard let self = self else { return }
            if let route = response?.routes.first {
                DispatchQueue.main.async { self.currentRoute = route }
            } else if let error = error {
                print("Directions error:", error.localizedDescription)
            }
        }
    }

    // MARK: - Favorites
    func saveFavorite(_ poi: POI) {
        PersistenceService.shared.save(poi: poi)
        var updatedPOI = poi
            updatedPOI.isFavorite = true
            favorites.removeAll { $0.id == updatedPOI.id }
            favorites.append(updatedPOI)
            if let index = pois.firstIndex(where: { $0.id == updatedPOI.id }) {
                pois[index].isFavorite = true
            }
        fetchFavoritesFromStorage()
    }

    func deleteFavorite(_ poi: POI) {
        PersistenceService.shared.delete(poi: poi)
        fetchFavoritesFromStorage()
    }

    func fetchFavorites() -> [POI] {
        favorites
    }

    private func fetchFavoritesFromStorage() {
        favorites = PersistenceService.shared.fetchFavorites().map {
            var updated = $0
            updated.isFavorite = true
            return updated
        }
    }

    // MARK: - Map Type
    func toggleMapType() {
        mapType = (mapType == .standard) ? .mutedStandard : .standard
    }

    // MARK: - Search Autocomplete
    func updateSearchQuery(_ query: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            guard query != self.completerService.currentQuery else { return }
            self.completerService.updateQuery(query)
        }
    }

    // MARK: - Center Map
    func centerOn(_ poi: POI) {
        let newRegion = MKCoordinateRegion(center: poi.coordinate,
                                           span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        DispatchQueue.main.async { self.region = newRegion }
    }
}
