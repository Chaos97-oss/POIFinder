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
    @Published var mapType: MKMapType = .standard
    @Published var recentSearches: [POI] = []
    @Published var currentRoute: MKRoute?
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792), 
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )

    private let searchService = POISearchService()
    private let completerService = SearchCompleterService()
    private var cancellables = Set<AnyCancellable>()

    init() {
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

        fetchFavoritesFromStorage()
    }

    func searchPOIs(
        query: String,
        near coordinate: CLLocationCoordinate2D,
        completion: ((POI) -> Void)? = nil
    ) {
        searchService.search(query: query, near: coordinate) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let results):
                    if results.isEmpty {
                        self?.errorMessage = "No results found for '\(query)'"
                    } else {
                        self?.pois = results
                        if let first = results.first {
                            completion?(first)
                        }
                    }
                case .failure(let error):
                    self?.errorMessage = "Search failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func addToRecentSearches(_ poi: POI) {
        recentSearches.removeAll(where: { $0.id == poi.id })
        recentSearches.insert(poi, at: 0)
        if recentSearches.count > 5 {
            recentSearches = Array(recentSearches.prefix(5))
        }
    }
    
    func updateNote(for poi: POI, note: String) {
            if let index = pois.firstIndex(where: { $0.id == poi.id }) {
                pois[index].note = note
            }
            if let index = favorites.firstIndex(where: { $0.id == poi.id }) {
                favorites[index].note = note
            }
    }
    
    func getDirections(to destination: CLLocationCoordinate2D, from source: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self else { return }
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self.currentRoute = route
                }
            } else if let error = error {
                print("Directions error:", error.localizedDescription)
            }
        }
    }
    

    
    func saveFavorite(_ poi: POI) {
        PersistenceService.shared.save(poi: poi)
        fetchFavoritesFromStorage()
    }
    
    func toggleMapType() {
        mapType = (mapType == .standard) ? .mutedStandard : .standard
    }

    func fetchFavorites() -> [POI] {
        return favorites
    }

    private func fetchFavoritesFromStorage() {
        favorites = PersistenceService.shared.fetchFavorites().map { poi in
            var updated = poi
            updated.isFavorite = true
            return updated
        }
    }

    func deleteFavorite(_ poi: POI) {
        PersistenceService.shared.delete(poi: poi)
        fetchFavoritesFromStorage()
    }

    func updateSearchQuery(_ query: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if query == self.completerService.currentQuery { return }
            self.completerService.updateQuery(query)
        }
    }

    
    func centerOn(_ poi: POI) {
        let newRegion = MKCoordinateRegion(
            center: poi.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        DispatchQueue.main.async {
            self.region = newRegion
        }
    }
}
