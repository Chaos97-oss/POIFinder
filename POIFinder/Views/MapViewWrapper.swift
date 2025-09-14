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
    var pois: [POI]
    var route: MKRoute?

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapViewWrapper

        init(_ parent: MapViewWrapper) {
            self.parent = parent
        }

        // 🔵 Handle pin rendering
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }

            let identifier = "POIAnnotation"
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

            if view == nil {
                view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                view?.canShowCallout = true
            } else {
                view?.annotation = annotation
            }

            if let poi = annotation as? POIAnnotation {
                switch poi.category {
                case "User":   view?.markerTintColor = .red
                case "Favorite": view?.markerTintColor = .yellow
                default:       view?.markerTintColor = .blue
                }
            }

            return view
        }

        // 🟢 Render polyline (directions)
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 4
                return renderer
            }
            return MKOverlayRenderer()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: true)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Update region
        uiView.setRegion(region, animated: true)

        // Clear annotations
        uiView.removeAnnotations(uiView.annotations)

        // Add annotations
        let annotations = pois.map { poi -> POIAnnotation in
            POIAnnotation(
                title: poi.name,
                subtitle: poi.address,
                coordinate: poi.coordinate,
                category: poi.isFavorite ? "Favorite" : poi.category
            )
        }
        uiView.addAnnotations(annotations)

        // Clear old route
        uiView.removeOverlays(uiView.overlays)

        // Draw new route if available
        if let route = route {
            uiView.addOverlay(route.polyline)
        }
    }
}

// 🔹 MKAnnotation wrapper for POI
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
