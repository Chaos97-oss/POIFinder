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

        private func markerColor(for annotation: POIAnnotation) -> UIColor {
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
            if isUserDraggingMap {
                parent.region = mapView.region
                isUserDraggingMap = false
            }
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
        syncRegion(uiView, context: context)
        updateAnnotations(on: uiView, context: context)
        uiView.mapType = mapType
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
        var incomingKeys = Set<String>()
        var newAnnotations: [POIAnnotation] = []

        for poi in pois {
            let key = context.coordinator.annotationKey(for: poi)
            incomingKeys.insert(key)

            if let existing = context.coordinator.annotationMap[key] {
                newAnnotations.append(existing)
            } else {
                let annotation = POIAnnotation(
                    title: poi.name,
                    subtitle: poi.address,
                    coordinate: poi.coordinate,
                    category: poi.isFavorite ? "Favorite" : poi.category
                )
                context.coordinator.annotationMap[key] = annotation
                newAnnotations.append(annotation)
            }
        }

        // Remove old annotations
        let keysToRemove = Set(context.coordinator.annotationMap.keys).subtracting(incomingKeys)
        for key in keysToRemove {
            if let ann = context.coordinator.annotationMap[key] {
                uiView.removeAnnotation(ann)
                context.coordinator.annotationMap.removeValue(forKey: key)
            }
        }

        // Add new annotations
        let existingKeys = Set(
            uiView.annotations.compactMap { $0 as? POIAnnotation }
                .map { context.coordinator.annotationKey(for: POI(name: $0.title ?? "", category: $0.category, address: $0.subtitle ?? "", coordinate: $0.coordinate)) }
        )

        for ann in newAnnotations where !existingKeys.contains(context.coordinator.annotationKey(for: POI(name: ann.title ?? "", category: ann.category, address: ann.subtitle ?? "", coordinate: ann.coordinate))) {
            uiView.addAnnotation(ann)
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
    let category: String

    init(title: String, subtitle: String, coordinate: CLLocationCoordinate2D, category: String) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.category = category
    }
}
