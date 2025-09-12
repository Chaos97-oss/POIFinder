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
        completer.resultTypes = .pointOfInterest
    }

    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }

    func completer(_ completer: MKLocalSearchCompleter, didUpdateResults results: [MKLocalSearchCompletion]) {
        suggestions = results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
           errorMessage = "Autocomplete failed: \(error.localizedDescription)"  
           suggestions = []
       }
}
