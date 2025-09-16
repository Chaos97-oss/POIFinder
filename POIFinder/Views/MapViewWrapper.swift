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
    @Binding var selectedPOI: POI?
    var pois: [POI]
    var route: MKRoute?

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWrapper
        var isUserDraggingMap = false
        let centerThreshold: CLLocationDegrees = 0.0005
        var annotationMap: [String: POIAnnotation] = [:]

        init(_ parent: MapViewWrapper) {
            self.parent = parent
        }

        // MARK: - Helpers
        func key(for poi: POI) -> String {
            "\(poi.coordinate.latitude),\(poi.coordinate.longitude)-\(poi.name)"
        }

        // MARK: - Annotation View
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "POIAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
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

        // MARK: - Route Drawing
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer()
        }

        // MARK: - Annotation Tap
        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                     calloutAccessoryControlTapped control: UIControl) {
            guard let poiAnn = view.annotation as? POIAnnotation else { return }

            if let match = parent.pois.first(where: {
                abs($0.coordinate.latitude - poiAnn.coordinate.latitude) < 1e-6 &&
                abs($0.coordinate.longitude - poiAnn.coordinate.longitude) < 1e-6 &&
                $0.name == poiAnn.title
            }) {
                parent.selectedPOI = match
            } else {
                parent.selectedPOI = POI(name: poiAnn.title ?? "Unknown",
                                         category: poiAnn.category,
                                         address: poiAnn.subtitle ?? "",
                                         coordinate: poiAnn.coordinate)
            }
        }

        // MARK: - Map Drag Handling
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            // Check if the change is triggered by user gesture
            if let gestureRecognizers = mapView.gestureRecognizers {
                for gr in gestureRecognizers {
                    if gr.state == .began || gr.state == .changed {
                        isUserDraggingMap = true
                        break
                    }
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            if isUserDraggingMap {
                parent.region = mapView.region
                isUserDraggingMap = false
            }
        }

        // MARK: - Show Route (on Get Directions)
        func showRoute(from source: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, on mapView: MKMapView) {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
            request.transportType = .automobile

            let directions = MKDirections(request: request)
            directions.calculate { [weak self] response, error in
                guard let self = self else { return }
                if let route = response?.routes.first {
                    DispatchQueue.main.async {
                        mapView.removeOverlays(mapView.overlays) // clear old route
                        mapView.addOverlay(route.polyline)
                        self.parent.route = route

                        mapView.setVisibleMapRect(
                            route.polyline.boundingMapRect,
                            edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40),
                            animated: true
                        )
                    }
                } else if let error = error {
                    print("Route error:", error.localizedDescription)
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
        // --- Sync region programmatically only if user is NOT dragging ---
        let uiCenter = uiView.region.center
        let newCenter = region.center
        let latDiff = abs(uiCenter.latitude - newCenter.latitude)
        let lonDiff = abs(uiCenter.longitude - newCenter.longitude)
        let threshold: CLLocationDegrees = 0.0005

        if !context.coordinator.isUserDraggingMap && (latDiff > threshold || lonDiff > threshold) {
            uiView.setRegion(region, animated: true)
        }

        // --- Efficient annotation update ---
        var incomingKeys = Set<String>()
        var incomingAnnotations: [POIAnnotation] = []

        for poi in pois {
            let key = "\(poi.coordinate.latitude),\(poi.coordinate.longitude)-\(poi.name)"
            incomingKeys.insert(key)
            if let existing = context.coordinator.annotationMap[key] {
                incomingAnnotations.append(existing)
            } else {
                let ann = POIAnnotation(
                    title: poi.name,
                    subtitle: poi.address,
                    coordinate: poi.coordinate,
                    category: poi.isFavorite ? "Favorite" : poi.category
                )
                context.coordinator.annotationMap[key] = ann
                incomingAnnotations.append(ann)
            }
        }

        // Remove old annotations
        let currentKeys = Set(context.coordinator.annotationMap.keys)
        let keysToRemove = currentKeys.subtracting(incomingKeys)
        for key in keysToRemove {
            if let ann = context.coordinator.annotationMap[key] {
                uiView.removeAnnotation(ann)
                context.coordinator.annotationMap.removeValue(forKey: key)
            }
        }

        // Add new annotations
        let existingAnnotations = Set(uiView.annotations.compactMap { $0 as? POIAnnotation }.map {
            "\($0.coordinate.latitude),\($0.coordinate.longitude)-\($0.title ?? "")"
        })

        for ann in incomingAnnotations {
            let key = "\(ann.coordinate.latitude),\(ann.coordinate.longitude)-\(ann.title ?? "")"
            if !existingAnnotations.contains(key) {
                uiView.addAnnotation(ann)
            }

            // --- Update marker color dynamically based on latest POI favorite status ---
            if let poi = pois.first(where: {
                $0.name == ann.title &&
                abs($0.coordinate.latitude - ann.coordinate.latitude) < 1e-6 &&
                abs($0.coordinate.longitude - ann.coordinate.longitude) < 1e-6
            }) {
                let color: UIColor = poi.isFavorite ? .systemYellow :
                    (poi.category == "User" ? .systemRed : .systemBlue)

                if let existingView = uiView.view(for: ann) as? MKMarkerAnnotationView {
                    existingView.markerTintColor = color
                }
            }
        }

        // --- Overlay drawing (polyline) ---
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
