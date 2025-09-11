//
//  FavoritesView.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import Foundation
import SwiftUI

struct FavoritesView: View {
    @ObservedObject var viewModel: MapViewModel

    var body: some View {
        NavigationView {
            List(viewModel.fetchFavorites()) { poi in
                Button(action: {
                    viewModel.selectedPOI = poi
                }) {
                    VStack(alignment: .leading) {
                        Text(poi.name).bold()
                        Text(poi.address).font(.subheadline).foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Favorites & History")
            .sheet(item: $viewModel.selectedPOI) { poi in
                POIDetailView(poi: poi)
            }
        }
    }
}
