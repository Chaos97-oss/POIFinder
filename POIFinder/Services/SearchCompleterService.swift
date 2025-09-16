//
//  SearchCompleterService.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import Foundation
import MapKit
import Combine

class SearchCompleterService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var errorMessage: String?
    
    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) {
        DispatchQueue.main.async {
            if query.isEmpty {
                self.suggestions = []
            } else {
                self.completer.queryFragment = query
            }
        }
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Autocomplete failed: \(error.localizedDescription)"
            self.suggestions = []
        }
    }
}

