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
            // MARK: - Map
            Map(coordinateRegion: $viewModel.region, annotationItems: allAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    annotationView(for: annotation)
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onReceive(locationManager.$userLocation) { newLocation in
                guard let coord = newLocation, !hasCenteredOnUser else { return }
                withAnimation(.easeInOut) {
                    viewModel.region.center = coord
                }
                hasCenteredOnUser = true
            }
            .sheet(item: $viewModel.selectedPOI) { poi in
                POIDetailView(poi: poi, viewModel: viewModel)
            }
            .sheet(isPresented: $showingFavorites) {
                FavoritesView(viewModel: viewModel) { selectedPOI in
                    // Callback when a POI is selected from favorites
                    showingFavorites = false
                    
                    // Update selectedPOI after the sheet is dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        viewModel.selectedPOI = selectedPOI
                        viewModel.centerOn(selectedPOI)
                    }
                }
            }
            
            // MARK: - Controls Overlay
            VStack(spacing: 10) {
                topControlButtons
                searchBar
                suggestionsList
                Spacer()
            }
            .padding(.top, 50)
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
        viewModel.centerOn(userPOI)
    }
    
    // MARK: - Search Bar
    private var searchBar: some View {
        HStack {
            TextField("Search places...", text: $searchQuery)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .submitLabel(.search)
                .onChange(of: searchQuery) { newValue in
                    viewModel.updateSearchQuery(newValue) // live suggestions
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
            
            // Perform search, then center on first POI
            performSearch(query: selectedTitle) { poi in
                viewModel.centerOn(poi)
            }
            
            // Delay clearing suggestions to avoid flicker
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
    
    // MARK: - Map Annotations
    private func annotationView(for annotation: POI) -> some View {
        Group {
            if annotation.category == "User" {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.red)
                    .font(.title)
            } else if annotation.isFavorite {
                Button(action: {
                    viewModel.selectedPOI = annotation
                    viewModel.centerOn(annotation)
                }) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.yellow)
                        .font(.title)
                        .scaleEffect(viewModel.selectedPOI?.id == annotation.id ? 1.3 : 1.0)
                        .animation(.easeInOut, value: viewModel.selectedPOI?.id)
                }
            } else {
                Button(action: {
                    viewModel.selectedPOI = annotation
                    viewModel.centerOn(annotation)
                }) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title)
                        .scaleEffect(viewModel.selectedPOI?.id == annotation.id ? 1.3 : 1.0)
                        .animation(.easeInOut, value: viewModel.selectedPOI?.id)
                }
            }
        }
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
        
        for fav in viewModel.favorites {
            if !annotations.contains(where: { $0.id == fav.id }) {
                annotations.append(fav)
            }
        }
        
        if let user = userAnnotation {
            annotations.append(user)
        }
        
        return annotations
    }
    
    private func performSearch(query: String? = nil, onResult: ((POI) -> Void)? = nil) {
        let coordinateToUse = locationManager.userLocation ?? viewModel.region.center
        let searchTerm = query ?? searchQuery
        guard !searchTerm.isEmpty else { return }
        viewModel.searchPOIs(query: searchTerm, near: coordinateToUse) { results in
            if let first = results.first {
                onResult?(first)
            }
        }
    }
}
