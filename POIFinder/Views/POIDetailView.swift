//
//  POIDetailView.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import Foundation
import SwiftUI

struct POIDetailView: View {
    let poi: POI
    @ObservedObject var viewModel: MapViewModel

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
        }
        .padding()
    }
}
