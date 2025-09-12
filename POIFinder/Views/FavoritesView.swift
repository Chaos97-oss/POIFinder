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
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading) {
            // Header
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Favorites")
                    .font(.title2)
                    .bold()
            }
            .padding(.horizontal)
            .padding(.top, 10)

            Divider()

            if viewModel.favorites.isEmpty {
                VStack {
                    Spacer()
                    Text("No Favorites yet")
                        .foregroundColor(.gray)
                        .italic()
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(viewModel.favorites) { poi in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(poi.name).bold()
                                Text(poi.address)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            // Navigate button
                            Button(action: {
                                // Only navigate, no delete
                                viewModel.selectedPOI = poi
                                viewModel.centerOn(poi)
                                dismiss()
                            }) {
                                Image(systemName: "arrow.up.right.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                            // Delete button
                            Button(action: {
                                viewModel.deleteFavorite(poi)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
