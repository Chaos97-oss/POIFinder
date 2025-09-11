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
    @State private var selectedPOIAnimationID = UUID() // for smooth annotation update

    var body: some View {
        ZStack(alignment: .top) {
            // Map in background
            Map(coordinateRegion: $region, annotationItems: viewModel.pois) { poi in
                MapAnnotation(coordinate: poi.coordinate) {
                    VStack {
                        // Main pin button
                        Button(action: {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.75, blendDuration: 0.5)) {
                                viewModel.selectedPOI = poi
                                region.center = poi.coordinate
                                region.span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
                            }
                        }) {
                            Image(systemName: viewModel.fetchFavorites().contains(where: { $0.id == poi.id }) ? "star.fill" : "mappin.circle.fill")
                                .foregroundColor(viewModel.fetchFavorites().contains(where: { $0.id == poi.id }) ? .yellow : .blue)
                                .font(.title)
                                .scaleEffect(viewModel.selectedPOI?.id == poi.id ? 1.3 : 1.0)
                                .animation(.easeInOut, value: viewModel.selectedPOI?.id)
                        }

                        // Optional: small save button under pin
                        if !viewModel.fetchFavorites().contains(where: { $0.id == poi.id }) {
                            Button(action: { viewModel.saveFavorite(poi) }) {
                                Image(systemName: "star")
                                    .foregroundColor(.orange)
                                    .padding(2)
                            }
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onReceive(locationManager.$userLocation) { newLocation in
                guard let coord = newLocation, !hasCenteredOnUser else { return }
                withAnimation(.easeInOut(duration: 1.0)) {
                    region.center = coord
                }
                hasCenteredOnUser = true
            }
            .onReceive(viewModel.$pois) { newPOIs in
                guard !newPOIs.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.8)) {
                    region.center = newPOIs.first!.coordinate
                }
            }
            .sheet(item: $viewModel.selectedPOI) { poi in
                POIDetailView(poi: poi)
            }

            // Controls overlay
            VStack(spacing: 10) {
                HStack {
                    TextField("Search places...", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .submitLabel(.search)
                        .onSubmit { performSearch() }

                    Button(action: {
                        print("Close tapped")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

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
    }

    private func performSearch(query: String? = nil) {
        let coordinateToUse = locationManager.userLocation ?? region.center
        let searchTerm = query ?? searchQuery
        guard !searchTerm.isEmpty else { return }
        viewModel.searchPOIs(query: searchTerm, near: coordinateToUse)
    }
}
