//
//  SettingsView.swift
//  Busyless
//
//  Created by Derrick Showers on 8/12/20.
//  Copyright © 2020 Derrick Showers. All rights reserved.
//

import SwiftUI
import BusylessDataLayer
import os

struct SettingsView: View {

    // MARK: - Private Properties

    @Environment(\.managedObjectContext)
    private var managedObjectContext

    @Environment(\.dataStore)
    private var dataStore

    @State private var isExportPresented: Bool = false
    @State private var isOnboardingPresented: Bool = false
    @State private var isDeleteAllAlertPresented: Bool = false

    private var iCloudStatusColor: Color {
        if FileManager.default.ubiquityIdentityToken != nil {
            return Color.green
        } else {
            return Color.red
        }
    }

    private var awakeTime: Binding<Date> {
        return Binding<Date>(
            get: { dataStore?.wrappedValue.userConfigStore.awakeTime ?? UserConfigStore.defaultAwakeTime },
            set: { dataStore?.wrappedValue.userConfigStore.awakeTime = $0 }
        )
    }

    private var sleepTime: Binding<Date> {
        return Binding<Date>(
            get: { dataStore?.wrappedValue.userConfigStore.sleepTime ?? UserConfigStore.defaultAwakeTime },
            set: { dataStore?.wrappedValue.userConfigStore.sleepTime = $0 }
        )
    }

    private var dataExportFile: URL {
        let exportManager = ExportManager(managedObjectContext: self.managedObjectContext)
        return exportManager.createActivityExportFile()
    }

    // MARK: - Lifecycle

    var body: some View {
        Form {
            Section(header: Text("TIMES")) {
                HStack {
                    DatePicker("Awake Time", selection: awakeTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.graphical)
                }
                HStack {
                    DatePicker("Sleepy Time", selection: sleepTime, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.graphical)
                }
            }
            Section {
                HStack {
                    Text("iCloud Status")
                    Spacer()
                    Circle()
                    .foregroundColor(iCloudStatusColor)
                        .fixedSize(horizontal: true, vertical: true)
                        .gesture(
                            LongPressGesture(minimumDuration: 10).onEnded { _ in
                                isDeleteAllAlertPresented = true
                            }
                        ).alert(isPresented: $isDeleteAllAlertPresented) {
                            Alert(title: Text("!! Delete All Activities !!"),
                                  message: Text("You found the super secret way to delete all activities. By tapping continue, all your activities will be deleted and cannot be undone. Are you sure?!?"),
                                  primaryButton: .destructive(Text("Continue 😱")) {
                                    self.dataStore?.wrappedValue.activityStore.deleteAllActivities()
                                  },
                                  secondaryButton: .cancel())
                        }

                }
            }
            Section {
                Button(action: {
                    isExportPresented.toggle()
                }, label: {
                    Text("Export data to CSV")
                })
                .sheet(isPresented: $isExportPresented, content: {
                    ActivityViewController(activityItems: [self.dataExportFile])
                })
                Link(destination: URL(string: "https://www.icloud.com/shortcuts/f2f66a8c23de4ec085771cd80fb1f512")!, label: {
                    Text("Add a focus shortcut")
                })
                Button(action: {
                    isOnboardingPresented.toggle()
                }, label: {
                    Text("Tell me more about Busyless")
                })
                .sheet(isPresented: $isOnboardingPresented, content: {
                    InitialOnboardingView()
                })
            }
        }

        .onDisappear {
            UserConfig.save(with: self.managedObjectContext)
        }
        .navigationBarTitle("Settings")
    }
}

private extension Date {
    static func today(withHour hour: Int) -> Date {
        var components = DateComponents()
        components.hour = hour
        return Calendar.current.date(from: components) ?? Date()
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        return SettingsView().environment(\.managedObjectContext, context)
    }
}
