//
//  PersistenceService.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import Foundation
import CoreData
import CoreLocation

class PersistenceService {
    static let shared = PersistenceService()
    private init() {}
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "POIFinder")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("CoreData failed to load: \(error)")
            }
        }
        return container
    }()

    var context: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // MARK: - Save POI
    func save(poi: POI) {
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "FavoritePOI")
        request.predicate = NSPredicate(
            format: "name == %@ AND latitude == %lf AND longitude == %lf",
            poi.name, poi.coordinate.latitude, poi.coordinate.longitude
        )

        do {
            let results = try context.fetch(request)
            let favorite: NSManagedObject

            if let existing = results.first {
                favorite = existing
            } else {
                let entity = NSEntityDescription.entity(forEntityName: "FavoritePOI", in: context)!
                favorite = NSManagedObject(entity: entity, insertInto: context)
            }

            favorite.setValue(poi.name, forKey: "name")
            favorite.setValue(poi.category, forKey: "category")
            favorite.setValue(poi.address, forKey: "address")
            favorite.setValue(poi.coordinate.latitude, forKey: "latitude")
            favorite.setValue(poi.coordinate.longitude, forKey: "longitude")
            favorite.setValue(poi.note, forKey: "note")

            try context.save()
            print("POI saved/updated: \(poi.name)")
        } catch {
            print("Failed to save POI: \(error)")
        }
    }

    // MARK: - Fetch Favorites
    func fetchFavorites() -> [POI] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "FavoritePOI")
        do {
            let results = try context.fetch(fetchRequest)
            return results.compactMap { fav in
                guard
                    let name = fav.value(forKey: "name") as? String,
                    let category = fav.value(forKey: "category") as? String,
                    let address = fav.value(forKey: "address") as? String,
                    let latitude = fav.value(forKey: "latitude") as? CLLocationDegrees,
                    let longitude = fav.value(forKey: "longitude") as? CLLocationDegrees
                else { return nil }

                return POI(
                    name: name,
                    category: category,
                    address: address,
                    coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                    note: fav.value(forKey: "note") as? String
                )
            }
        } catch {
            print("Failed to fetch favorites: \(error)")
            return []
        }
    }
    
    func updateNote(for poi: POI, note: String) {
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "FavoritePOI")
        request.predicate = NSPredicate(
            format: "name == %@ AND latitude == %lf AND longitude == %lf",
            poi.name, poi.coordinate.latitude, poi.coordinate.longitude
        )

        do {
            if let objectToUpdate = try context.fetch(request).first {
                objectToUpdate.setValue(note, forKey: "note")
                try context.save()
                print("Updated note for \(poi.name): \(note)")
            } else {
                print("POI not found in favorites, note not saved")
            }
        } catch {
            print("Failed to update note:", error)
        }
    }
    

    // MARK: - Delete POI
    func delete(poi: POI) {
        let context = context
        let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "FavoritePOI")
        request.predicate = NSPredicate(format: "name == %@", poi.name)
        do {
            if let objectToDelete = try context.fetch(request).first {
                context.delete(objectToDelete)
                try context.save()
                print("Deleted POI:", poi.name)
            }
        } catch {
            print("Failed to delete favorite:", error)
        }
    }
}
