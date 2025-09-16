//
//  POIDetailView.swift
//  POIFinder
//
//  Created by Chaos on 9/11/25.
//

import SwiftUI
import CoreLocation

struct POIDetailView: View {
    let poi: POI
    @ObservedObject var viewModel: MapViewModel
    var locationManager: LocationManager
    
    @State private var showingNoteEditor = false
    @State private var draftNote: String = ""


    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(poi.name)
                .font(.title)
                .bold()

            Text(poi.category)
                .font(.subheadline)
                .foregroundColor(.gray)

            Text(poi.address)
                .font(.body)
            if let existingNote = poi.note, !existingNote.isEmpty {
                            Text("Note: \(existingNote)")
                                .padding(.top, 8)
                                .foregroundColor(.secondary)
                        }

                        Button("Add/Edit Note") {
                            draftNote = poi.note ?? ""
                            showingNoteEditor = true
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(10)


            Spacer()

            Button(action: {
                viewModel.saveFavorite(poi)
            }) {
                HStack {
                    Image(systemName: "star.fill")
                    Text("Add to Favorites")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.yellow)
                .foregroundColor(.black)
                .cornerRadius(10)
            }

            Button(action: {
                if let userCoord = locationManager.userLocation {
                    viewModel.getDirections(to: poi.coordinate, from: userCoord)
                }
            }) {
                HStack {
                    Image(systemName: "car.fill")
                    Text("Get Directions")
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
               .sheet(isPresented: $showingNoteEditor) {
                   NavigationView {
                       VStack {
                           TextField("Enter note...", text: $draftNote, axis: .vertical)
                               .textFieldStyle(RoundedBorderTextFieldStyle())
                               .padding()

                           Spacer()
                       }
                       .navigationTitle("Edit Note")
                       .toolbar {
                           ToolbarItem(placement: .cancellationAction) {
                               Button("Cancel") { showingNoteEditor = false }
                           }
                           ToolbarItem(placement: .confirmationAction) {
                               Button("Save") {
                                   viewModel.updateNote(for: poi, note: draftNote)
                                   showingNoteEditor = false
                               }
                           }
                       }
                   }
               }
           }
       }
