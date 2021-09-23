//
//  AddNewActivityView.swift
//  Busyless
//
//  Created by Derrick Showers on 8/8/20.
//  Copyright © 2020 Derrick Showers. All rights reserved.
//

import SwiftUI
import Intents
import BusylessDataLayer
import os

struct AddNewActivityView: View {

    // MARK: - Public Properties

    let activity: Activity?
    let onComplete: () -> Void

    // MARK: - Private Properties

    @State private var name: String
    @State private var category: BLCategory?
    @State private var hoursDuration: Int
    @State private var minutesDuration: Int
    @State private var createdAt: Date
    @State private var notes: String

    @Environment(\.managedObjectContext)
    private var managedObjectContext

    @FocusState private var activityNameFocused: Bool

    private var isEditingExistingActivity: Bool

    private var readyToSave: Bool {
        return !name.isEmpty && (hoursDuration != 0 || minutesDuration != 0)
    }

    // MARK: - Lifecycle

    init(activity: Activity? = nil,
         preselectedCategory: BLCategory? = nil,
         onComplete: @escaping () -> Void) {
        self.activity = activity
        self.isEditingExistingActivity = activity != nil
        self.onComplete = onComplete
        _name = State(initialValue: activity?.name ?? "")
        _category = State(initialValue: activity?.category ?? preselectedCategory)
        _createdAt = State(initialValue: activity?.createdAt ?? Date())
        _notes = State(initialValue: activity?.notes ?? "")

        let calculatedDuration = activity?.duration.asHoursAndMinutes
        _hoursDuration = State(initialValue: calculatedDuration?.hours ?? 0)
        _minutesDuration = State(initialValue: calculatedDuration?.minutes ?? 30)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Spacer()) {
                    TextField("Activity Name", text: $name)
                        .focused($activityNameFocused)
                        .autocapitalization(.words)
                    NavigationLink(destination: CategorySelection(selectedCategory: $category)) {
                        Text("Category").bold()
                        Spacer()
                        Text("\(category?.name ?? "")")
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    HStack(alignment: .top) {
                        Text("Duration").bold()
                        Spacer()
                        VStack(alignment: .trailing) {
                            Stepper("\(hoursDuration) hrs", value: $hoursDuration, in: 0...23).fixedSize()
                            Spacer()
                            Stepper("\(minutesDuration) mins", value: $minutesDuration, in: 0...45, step: 15).fixedSize()
                        }
                    }
                    HStack {
                        Text("When?").bold()
                        Spacer()
                        DatePicker("When?", selection: $createdAt)
                            .datePickerStyle(.compact)
                            .frame(maxWidth: 250, maxHeight: 25)
                    }

                }
                Section(header: Text("NOTES")) {
                    TextEditor(text: $notes)
                }
            }
            .navigationBarTitle(isEditingExistingActivity ? "Edit Activity" : "Log New Activity")
            .navigationBarItems(leading:
                Button(action: {
                    onComplete()
                }, label: {
                    Text("Cancel")
                }), trailing:
                Button(action: {
                    self.addActivity()
                    self.donateAddNewActivityIntent()
                    onComplete()
                }, label: {
                    Text("Done")
                }).disabled(!readyToSave))
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            activityNameFocused = activity?.name == nil
        }
    }

    // MARK: - Private Methods

    private func donateAddNewActivityIntent() {
        let intent = AddNewActivityIntent()
        intent.name = self.name
        let totalDuration = TimeInterval.calculateTotalDurationFrom(hours: hoursDuration, minutes: minutesDuration)
        intent.durationInMinutes = NSNumber(value: (totalDuration / TimeInterval.oneHour) * TimeInterval.oneMinute)
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate(completion: nil)
    }
}

// MARK: - Core Data

extension AddNewActivityView {

    private func addActivity() {
        let activity = self.activity ?? Activity(context: managedObjectContext)
        activity.name = name
        activity.category = category
        activity.duration = TimeInterval.calculateTotalDurationFrom(hours: hoursDuration, minutes: minutesDuration)
        activity.notes = notes
        activity.createdAt = createdAt
        Activity.save(with: managedObjectContext)
    }
}

struct AddNewActivityView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let activity = Activity.mockActivity()
        return Group {
            AddNewActivityView { }
            AddNewActivityView(activity: activity) { }
                .environment(\.colorScheme, .dark)

        }.environment(\.managedObjectContext, context)
    }
}
