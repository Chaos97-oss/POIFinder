//
//  MapView.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import SwiftUI
import MapKit

struct MapView: View {
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var locationManager = LocationManager()
    @State private var searchQuery: String = ""
    @State private var hasCenteredOnUser = false
    @State private var showingFavorites = false

    private var isEditingDestination: Bool {
        !searchQuery.isEmpty || !viewModel.suggestions.isEmpty
    }

    var body: some View {
        ZStack(alignment: .top) {
            // MARK: - Map
            MapViewWrapper(
                region: $viewModel.region,
                selectedPOI: $viewModel.selectedPOI,
                pois: allAnnotations,
                route: viewModel.currentRoute,
                mapType: viewModel.mapType
            )
            .edgesIgnoringSafeArea(.all)
            .onReceive(locationManager.$userLocation) { newLocation in
                guard let coord = newLocation, !hasCenteredOnUser else { return }
                viewModel.userLocation = newLocation
                withAnimation { viewModel.region.center = coord }
                hasCenteredOnUser = true
            }
            .sheet(item: $viewModel.selectedPOI) { poi in
                POIDetailView(poi: poi, viewModel: viewModel, locationManager: locationManager)
            }

            // MARK: - UI Overlay
            VStack(spacing: 10) {
                topControlButtons
                searchBar
                if isEditingDestination {
                    suggestionsList
                }
                Spacer()
            }
            .padding(.top, 50)
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesView(viewModel: viewModel) { selectedPOI in
                showingFavorites = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    viewModel.centerOn(selectedPOI)
                    viewModel.selectedPOI = selectedPOI
                    if let userCoord = viewModel.userLocation {
                        viewModel.getDirections(to: selectedPOI.coordinate, from: userCoord)
                    }
                }
            }
        }
    }

    // MARK: - Top Buttons
    private var topControlButtons: some View {
        HStack(spacing: 20) {
            topButton("star.fill", color: .yellow) { showingFavorites = true }
            topButton("location.north.circle.fill", color: .blue) { centerOnUser() }
            topButton(viewModel.mapType == .standard ? "moon.circle.fill" : "sun.max.circle.fill",
                      color: .purple) { viewModel.toggleMapType() }
            Spacer()
        }
        .padding(.horizontal)
    }

    private func topButton(_ systemName: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: systemName).font(.title2).foregroundColor(color) }
    }

    private func centerOnUser() {
        guard let userCoord = locationManager.userLocation else { return }

        let targetRegion = MKCoordinateRegion(
            center: userCoord,
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05) // Normal zoom
        )
        DispatchQueue.main.async {
            var tempRegion = targetRegion
            tempRegion.center.latitude += 0.000001
            tempRegion.center.longitude += 0.000001
            self.viewModel.region = tempRegion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                withAnimation {
                    self.viewModel.region = targetRegion
                }
            }
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            TextField("Search places...", text: $searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.search)
                .onChange(of: searchQuery) { viewModel.updateSearchQuery($0) }
                .onSubmit { performSearch() }

            Spacer()

            if !searchQuery.isEmpty || !viewModel.suggestions.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal)
        .background(Color.white.opacity(0.9))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func clearSearch() {
        searchQuery = ""
        viewModel.suggestions = []
        hideKeyboard()
    }

    // MARK: - Suggestions & Recent Searches
    private var suggestionsList: some View {
        VStack(spacing: 0) {
            // Show recent searches first
            if !viewModel.recentSearches.isEmpty {
                ForEach(viewModel.recentSearches) { poi in
                    searchRow(title: poi.name, icon: "clock.fill") {
                        searchQuery = poi.name
                        hideKeyboard()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            withAnimation {
                                viewModel.centerOn(poi)
                                viewModel.selectedPOI = poi
                                viewModel.addToRecentSearches(poi)
                                viewModel.suggestions = []
                            }
                        }
                    }
                }
            }

            // Then show live suggestions
            if !viewModel.suggestions.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(viewModel.suggestions, id: \.self) { suggestion in
                            searchRow(title: suggestion.title, subtitle: suggestion.subtitle, icon: "magnifyingglass") {
                                let selectedTitle = suggestion.title
                                searchQuery = selectedTitle
                                hideKeyboard()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    performSearch(query: selectedTitle) { poi in
                                        withAnimation {
                                            viewModel.centerOn(poi)
                                            viewModel.selectedPOI = poi
                                            viewModel.addToRecentSearches(poi)
                                            viewModel.suggestions = []
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .background(Color.white.opacity(0.9))
        .cornerRadius(10)
        .padding(.horizontal)
        .animation(.easeInOut, value: viewModel.suggestions.count)
    }

    private func searchRow(title: String, subtitle: String = "", icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: subtitle.isEmpty ? 0 : 2) {
                HStack {
                    Image(systemName: icon).foregroundColor(.gray)
                    Text(title).bold()
                    Spacer()
                }
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundColor(.gray).padding(.leading, 24)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Helpers
    private var userAnnotation: POI? {
        guard let coord = locationManager.userLocation else { return nil }
        return POI(name: "You", category: "User", address: "Current Location", coordinate: coord)
    }

    private var allAnnotations: [POI] {
        let favs = viewModel.favorites.filter { fav in
            !viewModel.pois.contains(where: { $0.id == fav.id })
        }
        return viewModel.pois + favs + (userAnnotation.map { [$0] } ?? [])
    }

    private func performSearch(query: String? = nil, completion: ((POI) -> Void)? = nil) {
        let coordinateToUse = locationManager.userLocation ?? viewModel.region.center
        let searchTerm = query ?? searchQuery
        guard !searchTerm.isEmpty else { return }
        viewModel.searchPOIs(query: searchTerm, near: coordinateToUse, completion: completion)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
