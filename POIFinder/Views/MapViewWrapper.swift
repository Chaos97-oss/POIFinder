//
//  MapViewWrapper.swift
//  POIFinder
//
//  Created by Chaos on 9/14/25.
//

import SwiftUI
import MapKit

struct MapViewWrapper: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedPOI: POI?       // NEW: allow wrapper to set selection
    var pois: [POI]
    var route: MKRoute?

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWrapper
        // small threshold to detect programmatic vs user-initiated moves
        let centerThreshold: CLLocationDegrees = 0.0005
        // keep a map of existing annotations by an identifier (here: coordinate+title)
        var annotationMap: [String: POIAnnotation] = [:]

        init(_ parent: MapViewWrapper) {
            self.parent = parent
        }

        // Helper to make a stable key for a POI
        func key(for poi: POI) -> String {
            "\(poi.coordinate.latitude),\(poi.coordinate.longitude)-\(poi.name)"
        }

        // Provide annotation view with a callout accessory button
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "POIAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
                // add a detail disclosure button so taps are delivered
                let btn = UIButton(type: .detailDisclosure)
                view?.rightCalloutAccessoryView = btn
            } else {
                view?.annotation = annotation
            }

            if let poiAnn = annotation as? POIAnnotation {
                switch poiAnn.category {
                    case "User": view?.markerTintColor = .systemRed
                    case "Favorite": view?.markerTintColor = .systemYellow
                    default: view?.markerTintColor = .systemBlue
                }
            }

            return view
        }

        // When user taps the callout accessory
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                     calloutAccessoryControlTapped control: UIControl) {
            guard let poiAnn = view.annotation as? POIAnnotation else { return }

            // Find the POI in the parent's data (match by coordinate + title)
            if let match = parent.pois.first(where: {
                abs($0.coordinate.latitude - poiAnn.coordinate.latitude) < 1e-6 &&
                abs($0.coordinate.longitude - poiAnn.coordinate.longitude) < 1e-6 &&
                $0.name == poiAnn.title
            }) {
                // set the binding so SwiftUI can present sheet/detail
                parent.selectedPOI = match
            } else {
                // If not found in pois (maybe it's a favorite or user), try favorites
                // If parent has favorites tracked elsewhere, you can check them similarly.
                parent.selectedPOI = POI(name: poiAnn.title ?? "Unknown",
                                         category: poiAnn.category,
                                         address: poiAnn.subtitle ?? "",
                                         coordinate: poiAnn.coordinate)
            }
        }

        // Renderer for polyline overlay
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.lineWidth = 4
                renderer.strokeColor = UIColor.systemBlue
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        // Called when user pans/zooms the map — sync back to SwiftUI binding
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Avoid writing back if the difference is tiny
            let currentCenter = mapView.region.center
            let boundCenter = parent.region.center
            let latDiff = abs(currentCenter.latitude - boundCenter.latitude)
            let lonDiff = abs(currentCenter.longitude - boundCenter.longitude)

            if latDiff > centerThreshold || lonDiff > centerThreshold {
                DispatchQueue.main.async {
                    self.parent.region = mapView.region
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Only set region programmatically if it meaningfully differs from the map's current center.
        let uiCenter = uiView.region.center
        let newCenter = region.center
        let latDiff = abs(uiCenter.latitude - newCenter.latitude)
        let lonDiff = abs(uiCenter.longitude - newCenter.longitude)
        let threshold: CLLocationDegrees = 0.0005

        if latDiff > threshold || lonDiff > threshold {
            uiView.setRegion(region, animated: true)
        }

        // --- Efficient annotation update (don't remove all annotations) ---
        // Build keys for incoming pois
        var incomingKeys = Set<String>()
        var incomingAnnotations: [POIAnnotation] = []

        for poi in pois {
            let key = "\(poi.coordinate.latitude),\(poi.coordinate.longitude)-\(poi.name)"
            incomingKeys.insert(key)
            if let existing = context.coordinator.annotationMap[key] {
                incomingAnnotations.append(existing)
            } else {
                let ann = POIAnnotation(title: poi.name,
                                        subtitle: poi.address,
                                        coordinate: poi.coordinate,
                                        category: poi.isFavorite ? "Favorite" : poi.category)
                context.coordinator.annotationMap[key] = ann
                incomingAnnotations.append(ann)
            }
        }

        // Remove annotations that are no longer present
        let currentKeys = Set(context.coordinator.annotationMap.keys)
        let keysToRemove = currentKeys.subtracting(incomingKeys)
        for key in keysToRemove {
            if let ann = context.coordinator.annotationMap[key] {
                uiView.removeAnnotation(ann)
                context.coordinator.annotationMap.removeValue(forKey: key)
            }
        }

        // Find which incoming annotations need to be added to the map view
        let existingAnnotations = Set(uiView.annotations.compactMap { $0 as? POIAnnotation }.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)-\($0.title ?? "")" })
        for ann in incomingAnnotations {
            let key = "\(ann.coordinate.latitude),\(ann.coordinate.longitude)-\(ann.title ?? "")"
            if !existingAnnotations.contains(key) {
                uiView.addAnnotation(ann)
            }
        }

        // --- Overlay / Route handling ---
        // Remove non-route overlays
        uiView.overlays.forEach { uiView.removeOverlay($0) }

        if let route = route {
            uiView.addOverlay(route.polyline)
            // adjust visible rect so the whole route is visible with padding
            let padding = UIEdgeInsets(top: 120, left: 40, bottom: 120, right: 40)
            uiView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: padding, animated: true)
        }
    }
}

// MKAnnotation wrapper (unchanged)
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
