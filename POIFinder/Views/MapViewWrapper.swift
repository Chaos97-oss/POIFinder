//
//  MapViewWrapper.swift
//  POIFinder
//
//  Created by Chaos on 9/14/25.
//

import SwiftUI
import MapKit

// MARK: - MapViewWrapper
struct MapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedPOI: POI?
    var pois: [POI]
    var route: MKRoute?
    var mapType: MKMapType
    
    // MARK: - Coordinator
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWrapper
        var isUserDraggingMap = false
        var lastSyncedRegion: MKCoordinateRegion?
        var annotationMap: [String: POIAnnotation] = [:]
        
        private let centerThreshold: CLLocationDegrees = 0.0005

        
        init(_ parent: MapViewWrapper) {
            self.parent = parent
        }

        // MARK: Annotation Helpers
        func annotationKey(for poi: POI) -> String {
            "\(poi.coordinate.latitude),\(poi.coordinate.longitude)-\(poi.name)"
        }

        // MARK: - Annotations
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "POIAnnotation"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)

            view.annotation = annotation
            view.canShowCallout = true
            view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)

            if let poiAnn = annotation as? POIAnnotation {
                view.markerTintColor = markerColor(for: poiAnn)
            }

            return view
        }

        func markerColor(for annotation: POIAnnotation) -> UIColor {
            switch annotation.category {
            case "User": return .systemRed
            case "Favorite": return .systemYellow
            default: return .systemBlue
            }
        }

        // MARK: - Callout Tap
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                     calloutAccessoryControlTapped control: UIControl) {
            guard let poiAnn = view.annotation as? POIAnnotation else { return }

            let match = parent.pois.first {
                abs($0.coordinate.latitude - poiAnn.coordinate.latitude) < 1e-6 &&
                abs($0.coordinate.longitude - poiAnn.coordinate.longitude) < 1e-6 &&
                $0.name == poiAnn.title
            }

            parent.selectedPOI = match ?? POI(
                name: poiAnn.title ?? "Unknown",
                category: poiAnn.category,
                address: poiAnn.subtitle ?? "",
                coordinate: poiAnn.coordinate
            )
        }

        // MARK: - Map Gestures
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            if mapView.gestureRecognizers?.contains(where: { $0.state == .began || $0.state == .changed }) == true {
                isUserDraggingMap = true
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }

        // MARK: - Overlays
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else { return MKOverlayRenderer() }
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = .systemBlue
            renderer.lineWidth = 4
            return renderer
        }

        // MARK: - Directions
        func showRoute(from source: CLLocationCoordinate2D,
                       to destination: CLLocationCoordinate2D,
                       on mapView: MKMapView) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .automobile

            MKDirections(request: request).calculate { [weak self] response, error in
                guard let self = self, let route = response?.routes.first else {
                    if let error = error { print("Route error:", error.localizedDescription) }
                    return
                }

                DispatchQueue.main.async {
                    mapView.removeOverlays(mapView.overlays)
                    mapView.addOverlay(route.polyline)
                    self.parent.route = route

                    mapView.setVisibleMapRect(
                        route.polyline.boundingMapRect,
                        edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                        animated: true
                    )
                }
            }
        }
    }

    // MARK: - UIViewRepresentable
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.setRegion(region, animated: false)
        mapView.mapType = mapType
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let coord = region.center
        if !context.coordinator.isUserDraggingMap {
            if let last = context.coordinator.lastSyncedRegion {
                let diffLat = abs(last.center.latitude - coord.latitude)
                let diffLon = abs(last.center.longitude - coord.longitude)
                if diffLat > 0.0008 || diffLon > 0.0008 {
                    uiView.setRegion(region, animated: true)
                    context.coordinator.lastSyncedRegion = region
                }
            } else {
                uiView.setRegion(region, animated: false)
                context.coordinator.lastSyncedRegion = region
            }
        }
        updateAnnotations(on: uiView, context: context)
        if uiView.mapType != mapType {
            uiView.mapType = mapType
        }
        updateRoute(on: uiView)
    }
    
    
    // MARK: - Region Sync
    private func syncRegion(_ uiView: MKMapView, context: Context) {
        let diffLat = abs(uiView.region.center.latitude - region.center.latitude)
        let diffLon = abs(uiView.region.center.longitude - region.center.longitude)
        let threshold: CLLocationDegrees = 0.0005

        if !context.coordinator.isUserDraggingMap && (diffLat > threshold || diffLon > threshold) {
            uiView.setRegion(region, animated: true)
        }
    }

    // MARK: - Annotations
    private func updateAnnotations(on uiView: MKMapView, context: Context) {
        let newKeys = Set(pois.map { context.coordinator.annotationKey(for: $0) })
        let oldKeys = Set(context.coordinator.annotationMap.keys)
        
        // --- Add new annotations ---
        let keysToAdd = newKeys.subtracting(oldKeys)
        for poi in pois where keysToAdd.contains(context.coordinator.annotationKey(for: poi)) {
            let annotation = POIAnnotation(
                title: poi.name,
                subtitle: poi.address,
                coordinate: poi.coordinate,
                category: poi.isFavorite ? "Favorite" : poi.category
            )
            context.coordinator.annotationMap[context.coordinator.annotationKey(for: poi)] = annotation
            uiView.addAnnotation(annotation)
        }
        // --- Remove old annotations ---
        let keysToRemove = oldKeys.subtracting(newKeys)
        for key in keysToRemove {
            if let ann = context.coordinator.annotationMap[key] {
                uiView.removeAnnotation(ann)
                context.coordinator.annotationMap.removeValue(forKey: key)
            }
        }
        // ---  Update existing annotations if category changed ---
        for poi in pois {
            let key = context.coordinator.annotationKey(for: poi)
            if let ann = context.coordinator.annotationMap[key] {
                let newCategory = poi.isFavorite ? "Favorite" : poi.category
                if ann.category != newCategory {
                    ann.category = newCategory
                    if let view = uiView.view(for: ann) as? MKMarkerAnnotationView {
                        view.markerTintColor = context.coordinator.markerColor(for: ann)
                    }
                }
            }
        }
    }

    // MARK: - Routes
    private func updateRoute(on uiView: MKMapView) {
        let existingPolylines = uiView.overlays.compactMap { $0 as? MKPolyline }

        if let route = route {
            if !existingPolylines.contains(where: { $0 === route.polyline }) {
                uiView.removeOverlays(existingPolylines)
                uiView.addOverlay(route.polyline)
                uiView.setVisibleMapRect(
                    route.polyline.boundingMapRect,
                    edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                    animated: true
                )
            }
        } else {
            uiView.removeOverlays(existingPolylines)
        }
    }
}

    // MARK: - POIAnnotation
    class POIAnnotation: NSObject, MKAnnotation {
        let title: String?
        let subtitle: String?
        let coordinate: CLLocationCoordinate2D
        var category: String

        init(title: String, subtitle: String, coordinate: CLLocationCoordinate2D, category: String) {
            self.title = title
            self.subtitle = subtitle
            self.coordinate = coordinate
            self.category = category
        }
}
