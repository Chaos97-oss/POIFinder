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

    var body: some View {
        ZStack(alignment: .top) {
            // --- Map with wrapper
            MapViewWrapper(
                region: $viewModel.region,
                selectedPOI: $viewModel.selectedPOI,
                pois: allAnnotations,
                route: viewModel.currentRoute
            )
            .edgesIgnoringSafeArea(.all)
            .onReceive(locationManager.$userLocation) { newLocation in
                guard let coord = newLocation, !hasCenteredOnUser else { return }
                viewModel.userLocation = newLocation
                withAnimation {
                    viewModel.region.center = coord
                }
                hasCenteredOnUser = true
            }
            .sheet(item: $viewModel.selectedPOI, onDismiss: {
                viewModel.selectedPOI = nil
            }) { poi in
                POIDetailView(poi: poi, viewModel: viewModel, locationManager: locationManager)
            }

            // --- Overlay controls
            VStack(spacing: 10) {
                topControlButtons
                searchBar
                suggestionsList
                Spacer()
            }
            .padding(.top, 50)
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesView(viewModel: viewModel, onSelect: { selectedPOI in
                showingFavorites = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    viewModel.centerOn(selectedPOI)
                    viewModel.selectedPOI = selectedPOI
                    if let userCoord = viewModel.userLocation {
                    viewModel.getDirections(to: selectedPOI.coordinate, from: userCoord)
                }
                }
            })
        }
    }

    // MARK: - Top Buttons
    private var topControlButtons: some View {
        HStack {
            Button(action: { showingFavorites = true }) {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)
            }

            Button(action: centerOnUser) {
                Image(systemName: "location.north.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    private func centerOnUser() {
        guard let userCoord = locationManager.userLocation else { return }
        let userPOI = POI(
            name: "You",
            category: "User",
            address: "Current Location",
            coordinate: userCoord
        )
        withAnimation {
            viewModel.centerOn(userPOI)
        }
    }

    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            TextField("Search places...", text: $searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.search)
                .onChange(of: searchQuery) { newValue in
                    viewModel.updateSearchQuery(newValue)
                }
                .onSubmit { performSearch() }

            Spacer()

            if !searchQuery.isEmpty || !viewModel.suggestions.isEmpty {
                Button(action: clearSearch) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal)
    }

    private func clearSearch() {
        searchQuery = ""
        viewModel.suggestions = []
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Suggestions List
    private var suggestionsList: some View {
        if !viewModel.suggestions.isEmpty {
            return AnyView(
                List(viewModel.suggestions, id: \.self) { suggestion in
        Button(action: {
            let selectedTitle = suggestion.title
            searchQuery = selectedTitle
            performSearch(query: selectedTitle) { poi in
                viewModel.centerOn(poi)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                viewModel.suggestions = []
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )
                    }
                    }) {
                        VStack(alignment: .leading) {
                            Text(suggestion.title).bold()
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
                .padding(.horizontal)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.suggestions.count)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Helpers
    private var userAnnotation: POI? {
        guard let coord = locationManager.userLocation else { return nil }
        return POI(
            name: "You",
            category: "User",
            address: "Current Location",
            coordinate: coord
        )
    }

    private var allAnnotations: [POI] {
        var annotations = viewModel.pois

        for fav in viewModel.favorites where !annotations.contains(where: { $0.id == fav.id }) {
            annotations.append(fav)
        }

        if let user = userAnnotation {
            annotations.append(user)
        }

        return annotations
    }

    private func performSearch(query: String? = nil, completion: ((POI) -> Void)? = nil) {
        let coordinateToUse = locationManager.userLocation ?? viewModel.region.center
        let searchTerm = query ?? searchQuery
        guard !searchTerm.isEmpty else { return }
        
        viewModel.searchPOIs(query: searchTerm, near: coordinateToUse) { poi in
            completion?(poi)
        }
    }
    
}
