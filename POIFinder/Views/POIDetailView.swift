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

    var body: some View {
        VStack(spacing: 16) {
            Text(poi.name)
                .font(.title)
                .fontWeight(.bold)

            Text(poi.category)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(poi.address)
                .font(.body)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }
}
