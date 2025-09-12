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
            // Map with merged annotations (POIs + user + favorites)
            Map(coordinateRegion: $viewModel.region, annotationItems: allAnnotations) { (annotation: POI) in
                MapAnnotation(coordinate: annotation.coordinate) {
                    if annotation.category == "User" {
                        // 🔴 Red pin for user
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.title)

                    } else if annotation.isFavorite {
                        // ⭐️ Yellow pin for favorites
                        Button(action: {
                            viewModel.selectedPOI = annotation
                            viewModel.centerOn(annotation) // smooth animation
                        }) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(.yellow)
                                .font(.title)
                                .scaleEffect(viewModel.selectedPOI?.id == annotation.id ? 1.3 : 1.0)
                                .animation(.easeInOut, value: viewModel.selectedPOI?.id)
                        }

                    } else {
                        // 🔵 Blue pin for normal POIs
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
            .edgesIgnoringSafeArea(.all)
            .onReceive(locationManager.$userLocation) { newLocation in
                guard let coord = newLocation, !hasCenteredOnUser else { return }
                withAnimation {
                    viewModel.region.center = coord
                }
                hasCenteredOnUser = true
            }
            .sheet(item: $viewModel.selectedPOI, onDismiss: {
                viewModel.selectedPOI = nil
            }) { poi in
                POIDetailView(poi: poi, viewModel: viewModel)
            }

            // Controls overlay
            VStack(spacing: 10) {
                HStack {
                    Button(action: { showingFavorites = true }) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                    }

                    Button(action: {
                        guard let userCoord = locationManager.userLocation else { return }
                        let userPOI = POI(
                            name: "You",
                            category: "User",
                            address: "Current Location",
                            coordinate: userCoord
                        )
                        viewModel.centerOn(userPOI)
                    }) {
                        Image(systemName: "location.north.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }

                    Spacer()

                    Button(action: { print("Close tapped") }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

                TextField("Search places...", text: $searchQuery)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .submitLabel(.search)
                    .onSubmit { performSearch() }

                if !viewModel.suggestions.isEmpty {
                    List(viewModel.suggestions, id: \.self) { suggestion in
                        Button(action: {
                            searchQuery = suggestion.title
                            performSearch(query: suggestion.title)
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
                }

                Spacer()
            }
            .padding(.top, 50)
        }
        .sheet(isPresented: $showingFavorites) {
            FavoritesView(viewModel: viewModel)
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

    // Merge POIs, favorites, and user safely
    private var allAnnotations: [POI] {
        var annotations = viewModel.pois
        
        // Add favorites if not already included
        for fav in viewModel.favorites {
            if !annotations.contains(where: { $0.id == fav.id }) {
                annotations.append(fav)
            }
        }
        
        // Add user location
        if let user = userAnnotation {
            annotations.append(user)
        }
        
        return annotations
    }

    private func performSearch(query: String? = nil) {
        let coordinateToUse = locationManager.userLocation ?? viewModel.region.center
        let searchTerm = query ?? searchQuery
        guard !searchTerm.isEmpty else { return }
        viewModel.searchPOIs(query: searchTerm, near: coordinateToUse)
    }
}
