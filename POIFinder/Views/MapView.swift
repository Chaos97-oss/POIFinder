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
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var hasCenteredOnUser = false
    @State private var showingFavorites = false

    var body: some View {
        ZStack(alignment: .top) {
            // Map with merged annotations (POIs + optional user)
            Map(coordinateRegion: $region, annotationItems: allAnnotations) { (annotation: POI) in
                MapAnnotation(coordinate: annotation.coordinate) {
                    // Distinguish user marker by id
                    if annotation.category == "User" {
                        // Red pin for user
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(.red)
                            .font(.title)
                    } else {
                        // Blue pin for POIs
                        Button(action: {
                            viewModel.selectedPOI = annotation
                            region.center = annotation.coordinate
                            region.span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
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
                region.center = coord
                hasCenteredOnUser = true
            }
            .onReceive(viewModel.$pois) { newPOIs in
                guard !newPOIs.isEmpty else { return }
                region.center = newPOIs.first!.coordinate
            }
            .sheet(item: $viewModel.selectedPOI) { poi in
                POIDetailView(poi: poi, viewModel: viewModel)
            }

            // Controls overlay (favorites, compass, close, search)
            VStack(spacing: 10) {
                HStack {
                    Button(action: { showingFavorites = true }) {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                    }

                    Button(action: {
                        guard let userCoord = locationManager.userLocation else { return }
                        region.center = userCoord
                        region.span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
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

    // Create a "user" POI if user location exists (so it merges cleanly with POIs)
    private var userAnnotation: POI? {
        guard let coord = locationManager.userLocation else { return nil }
        return POI(
            name: "You",
            category: "User",             // placeholder for required field
            address: "Current Location",  // placeholder for required field
            coordinate: coord
        )
    }

    // Merge POIs from the view model with the optional user annotation.
    // Keep the POIs first so selecting shows them correctly.
    private var allAnnotations: [POI] {
        if let user = userAnnotation {
            // put user at the end to avoid accidental equality with real POIs
            return viewModel.pois + [user]
        } else {
            return viewModel.pois
        }
    }

    private func performSearch(query: String? = nil) {
        let coordinateToUse = locationManager.userLocation ?? region.center
        let searchTerm = query ?? searchQuery
        guard !searchTerm.isEmpty else { return }
        viewModel.searchPOIs(query: searchTerm, near: coordinateToUse)
    }
}
