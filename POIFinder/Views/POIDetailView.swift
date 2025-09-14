//
//  POIDetailView.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import SwiftUI
import CoreLocation

struct POIDetailView: View {
    let poi: POI
    @ObservedObject var viewModel: MapViewModel
    var locationManager: LocationManager   // 👈 Inject this

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(poi.name)
                .font(.title)
                .bold()

            Text(poi.category)
                .font(.subheadline)
                .foregroundColor(.gray)

            Text(poi.address)
                .font(.body)

            Spacer()

            Button(action: {
                viewModel.saveFavorite(poi)
            }) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Add to Favorites")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.yellow)
                .foregroundColor(.black)
                .cornerRadius(10)
            }

            Button(action: {
                if let userCoord = locationManager.userLocation {
                    viewModel.getDirections(to: poi.coordinate, from: userCoord)
                }
            }) {
                HStack {
                    Image(systemName: "car.fill")
                    Text("Get Directions")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
    }
}
