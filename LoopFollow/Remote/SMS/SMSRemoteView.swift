// LoopFollow
// SMSRemoteView.swift
// Created by codebymini.

import HealthKit
import SwiftUI

struct SMSRemoteView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = RemoteSettingsViewModel()
    @State private var showingBolusSheet = false
    @State private var showingCarbsSheet = false
    @State private var showingTargetSheet = false
    @State private var showingBGSheet = false
    @State private var showingLoopSheet = false
    @State private var showingPumpSheet = false
    @State private var showingProfileSheet = false
    @State private var showingStatusSheet = false

    var body: some View {
        NavigationView {
            VStack {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ]

                if viewModel.smsSetup {
                    // Show SMS command buttons if SMS setup configured
                    LazyVGrid(columns: columns, spacing: 16) {
                        Button(action: { showingBGSheet = true }) {
                            CommandButtonContent(command: "BG Status", iconName: "heart.fill")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { showingBolusSheet = true }) {
                            CommandButtonContent(command: "Bolus", iconName: "syringe")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { showingCarbsSheet = true }) {
                            CommandButtonContent(command: "Carbs", iconName: "fork.knife")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { showingTargetSheet = true }) {
                            CommandButtonContent(command: "Target", iconName: "target")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { showingLoopSheet = true }) {
                            CommandButtonContent(command: "Loop Control", iconName: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { showingPumpSheet = true }) {
                            CommandButtonContent(command: "Pump Control", iconName: "cylinder")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { showingProfileSheet = true }) {
                            CommandButtonContent(command: "Profile", iconName: "person.crop.circle")
                        }
                        .buttonStyle(PlainButtonStyle())

                        Button(action: { showingStatusSheet = true }) {
                            CommandButtonContent(command: "Status", iconName: "info.circle")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                } else {
                    // Show setup message if SMS is not configured
                    VStack(spacing: 32) {
                        Spacer()

                        Image(systemName: "message")
                            .font(.system(size: 80))
                            .foregroundColor(.orange)

                        VStack(spacing: 16) {
                            Text("Android APS SMS Commands Not Configured")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Please configure SMS settings in Remote Settings to use Android APS SMS commands.")
                                .font(.body)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 32)
                        }

                        NavigationLink(destination: RemoteSettingsView(viewModel: viewModel)) {
                            HStack(spacing: 12) {
                                Image(systemName: "gear")
                                    .font(.system(size: 18))
                                Text("Configure Android APS SMS Commands")
                                    .font(.headline)
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
                Spacer()
            }
            .navigationBarTitle("SMS Remote Control", displayMode: .inline)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingBolusSheet) {
            SMSBolusView()
        }
        .sheet(isPresented: $showingCarbsSheet) {
            SMSCarbsView()
        }
        .sheet(isPresented: $showingTargetSheet) {
            SMSTargetView()
        }
        .sheet(isPresented: $showingBGSheet) {
            SMSBGView()
        }
        .sheet(isPresented: $showingLoopSheet) {
            SMSLoopView()
        }
        .sheet(isPresented: $showingPumpSheet) {
            SMSPumpView()
        }
        .sheet(isPresented: $showingProfileSheet) {
            SMSProfileView()
        }
        .sheet(isPresented: $showingStatusSheet) {
            SMSStatusView()
        }
    }
}

struct CommandButtonContent: View {
    let command: String
    let iconName: String

    var body: some View {
        VStack {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
            Text(command)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}

#Preview {
    SMSRemoteView()
}
