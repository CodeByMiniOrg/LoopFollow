// LoopFollow
// TrioRemoteControlView.swift
// Created by Jonas Björkert.

import SwiftUI

struct TrioRemoteControlView: View {
    @ObservedObject var viewModel: TrioRemoteControlViewModel
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView {
            VStack {
                let columns = [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                ]

                LazyVGrid(columns: columns, spacing: 16) {
                    CommandButtonView(command: "Meal", iconName: "fork.knife", destination: MealView())
                    CommandButtonView(command: "Bolus", iconName: "syringe", destination: BolusView())
                    CommandButtonView(command: "Temp Target", iconName: "scope", destination: TempTargetView())
                    CommandButtonView(command: "Overrides", iconName: "slider.horizontal.3", destination: OverrideView())
                }
                .padding(.horizontal)

                Spacer()
            }
            .navigationBarTitle("Trio Remote Control", displayMode: .inline)
        }
    }
}
