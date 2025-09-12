////
////  POIFinderTests.swift
////  POIFinderTests
////
////  Created by Chaos on 9/11/25.
////
//
//import XCTest
//import CoreLocation
//@testable import POIFinder
//
//final class MapScreenTests: XCTestCase {
//
//    func testPOIEquality() {
//        let coord = CLLocationCoordinate2D(latitude: 6.5244, longitude: 3.3792)
//
//        let poi1 = POI(name: "Test", category: "Restaurant", address: "Lagos", coordinate: coord)
//        let poi2 = POI(name: "Test", category: "Restaurant", address: "Lagos", coordinate: coord)
//
//        // Equality is based on UUID — different UUIDs should not be equal
//        XCTAssertNotEqual(poi1, poi2)
//    }
//
//    func testUserAnnotationPOI() {
//        let location = CLLocationCoordinate2D(latitude: 10.0, longitude: 20.0)
//        let userPOI = POI(name: "You", category: "User", address: "Current Location", coordinate: location)
//
//        XCTAssertEqual(userPOI.name, "You")
//        XCTAssertEqual(userPOI.category, "User")
//        XCTAssertEqual(userPOI.address, "Current Location")
//        XCTAssertEqual(userPOI.coordinate.latitude, 10.0)
//        XCTAssertEqual(userPOI.coordinate.longitude, 20.0)
//    }
//
//    func testPOIHashable() {
//        let coord = CLLocationCoordinate2D(latitude: 1.0, longitude: 2.0)
//        let poi = POI(name: "Place", category: "Test", address: "Somewhere", coordinate: coord)
//
//        let set: Set<POI> = [poi]
//        XCTAssertTrue(set.contains(poi))
//    }
//}
