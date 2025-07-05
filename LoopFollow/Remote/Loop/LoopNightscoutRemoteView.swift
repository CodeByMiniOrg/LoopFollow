// LoopFollow
// LoopNightscoutRemoteView.swift
// Created by Jonas Björkert.

import SwiftUI

struct LoopNightscoutRemoteView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var nsAdmin = Storage.shared.nsWriteAuth
    
    private let controller = LoopNightscoutRemoteController()
    @State private var showLooperSetup = false

    var body: some View {
        NavigationView {
            if !nsAdmin.value {
                ErrorMessageView(
                    message: "Please update your token to include the 'admin' role in order to do remote commands with Loop."
                )
            } else {
                VStack {
                    // Looper Status Section
                    if let currentLooper = controller.getCurrentLooper() {
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "person.crop.circle.fill")
                                    .foregroundColor(.green)
                                Text("Connected to: \(currentLooper.name)")
                                    .font(.headline)
                            }
                            
                            Text("Nightscout: \(currentLooper.nightscoutCredentials.url.host ?? "Unknown")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    } else {
                        VStack(spacing: 10) {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.exclamationmark")
                                    .foregroundColor(.orange)
                                Text("No Looper Connected")
                                    .font(.headline)
                            }
                            
                            Text("Add a looper to enable remote bolus and carb delivery")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Remote Commands Grid
                    let columns = [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                    ]

                    LazyVGrid(columns: columns, spacing: 16) {
                        CommandButtonView(command: "Bolus", iconName: "syringe", destination: LoopBolusView())
                        CommandButtonView(command: "Carbs", iconName: "fork.knife", destination: LoopCarbView())
                        CommandButtonView(command: "Overrides", iconName: "slider.horizontal.3", destination: LoopOverrideView())
                        
                        // Add Looper button
                        Button(action: {
                            showLooperSetup = true
                        }) {
                            VStack {
                                Image(systemName: "person.badge.plus")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                Text("Add Looper")
                            }
                            .frame(maxWidth: .infinity, minHeight: 100)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .navigationBarTitle("Loop Remote Control", displayMode: .inline)
                .sheet(isPresented: $showLooperSetup) {
                    LooperSetupView()
                }
            }
        }
    }
}
