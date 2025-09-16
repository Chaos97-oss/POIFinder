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
    @Published var currentRoute: MKRoute?
    @Published var userLocation: CLLocationCoordinate2D?
    
    //  New: Track the visible map region
    @Published var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792), // default Lagos, Nigeria
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
    
    func getDirections(to destination: CLLocationCoordinate2D, from userLocation: CLLocationCoordinate2D) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: userLocation))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            if let route = response?.routes.first {
                DispatchQueue.main.async {
                    self?.currentRoute = route
                    self?.region = MKCoordinateRegion(route.polyline.boundingMapRect)
                }
            }
        }
    }
    
//    func clearRoute() {
//            route = nil
//        }
    
    func saveFavorite(_ poi: POI) {
        PersistenceService.shared.save(poi: poi)
        fetchFavoritesFromStorage()
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
        completerService.updateQuery(query)
    }

    // 👇 New: Re-center map on a favorite or POI
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
