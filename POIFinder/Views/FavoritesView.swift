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
            // Bold header with star
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

                            Button(action: {
                                viewModel.deleteFavorite(poi)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .contentShape(Rectangle()) // Makes entire row tappable
                        .onTapGesture {
                            // 👇 move map & show details
                            viewModel.centerOn(poi)
                            viewModel.selectedPOI = poi
                            dismiss()
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
