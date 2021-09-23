//
//  DayView.swift
//  Busyless
//
//  Created by Derrick Showers on 8/8/20.
//  Copyright © 2020 Derrick Showers. All rights reserved.
//

import SwiftUI
import CoreData
import BusylessDataLayer
import os

struct DayView: View {

    // MARK: - Properties

    enum ActiveSheet: Identifiable {
        case addNewCategory, manageContextCategory, addNewActivity

        var id: Int {
            hashValue
        }
    }

    @State var activeSheet: ActiveSheet?

    @Environment(\.presentationMode)
    private var presentationMode: Binding<PresentationMode>

    @Environment(\.managedObjectContext)
    private var managedObjectContext

    @Environment(\.dataStore)
    private var dataStore

    private var totalBudgetedDuration: TimeInterval {
        return self.categories.reduce(0) { $0 + $1.dailyBudgetDuration }
    }

    private var categories: [BLCategory] {
        return dataStore?.wrappedValue.categoryStore.allCategories ?? []
    }

    private var contextCategories: [ContextCategory] {
        return dataStore?.wrappedValue.categoryStore.allContextCategories ?? []
    }

    private var categoriesWithNoContextCategory: [BLCategory] {
        return categories.filter { $0.contextCategory == nil }
    }

    private var awakeDuration: TimeInterval {
        guard let awakeTime = dataStore?.wrappedValue.userConfigStore.awakeTime,
              let sleepTime = dataStore?.wrappedValue.userConfigStore.sleepTime else {
            return UserConfigStore.awakeDurationDefault
        }

        // If sleep time is before awake time, 1 day needs to be added to get correct duration.
        var validatedSleepTime = sleepTime
        if sleepTime < awakeTime {
            validatedSleepTime = Calendar.current.date(byAdding: .day, value: 1, to: sleepTime) ?? sleepTime
        }

        let difference = Calendar.current.dateComponents([.hour, .minute], from: awakeTime, to: validatedSleepTime)
        return TimeInterval(difference.hour ?? 0) * TimeInterval.oneHour
    }

    // MARK: - Testing

    var didAppear: ((Self) -> Void)?

    // MARK: - Lifecycle

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                TodayStatus(awakeDuration: awakeDuration, totalBudgetedDuration: totalBudgetedDuration)
                List {
                    // Categories with a context category
                    ForEach(contextCategories, id: \.name) { (contextCategory: ContextCategory) in
                        if let categories = (contextCategory.categories?.allObjects as? [BLCategory])?.sorted { $0.name ?? "" < $1.name ?? "" } {
                            contextCategorySection(title: contextCategory.name,
                                                   subtitle: contextCategory.timeBudgeted.hoursMinutesString,
                                                   categories: categories) { row in
                                deleteCategory(at: row.map({$0}).first ?? 0, contextCategory: contextCategory)
                            }
                        }
                    }.listRowBackground(Color.customWhite)

                    // All other categories
                    contextCategorySection(categories: categoriesWithNoContextCategory) { (row) in
                        deleteCategory(at: row.map({$0}).first ?? 0)
                    }.listRowBackground(Color.customWhite)
                }.listStyle(.plain)
            }
            .onAppear { self.didAppear?(self) }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    AddButton {
                        activeSheet = .addNewActivity
                    }
                }
            }

            EmptyView()
                .navigationBarTitle("Today")
                .navigationBarItems(trailing: MoreOptionsMenuButton(categories: categories,
                                                                    addCategoryAction: {
                                                                        activeSheet = .addNewCategory
                                                                    }, addContextCategoryAction: {
                                                                        activeSheet = .manageContextCategory
                                                                    }))
        }
        .background(Color(UIColor.systemGray6))
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .addNewActivity:
                AddNewActivityView {
                    activeSheet = nil
                }
            case .addNewCategory:
                AddNewCategoryView {
                    addCategory(name: $0)
                    activeSheet = nil
                }
            case .manageContextCategory:
                ManageContextCategoryView(contextCategories: contextCategories, onAdd: {
                    addContextCategory(name: $0)
                }, onDelete: {
                    deleteContextCategories($0)
                }, onComplete: {
                    activeSheet = nil
                })
            }
        }
    }

    // MARK: - Private Methods

    private func contextCategorySection(title: String? = nil,
                                        subtitle: String? = nil,
                                        categories: [BLCategory],
                                        onDelete: @escaping (IndexSet) -> Void) -> some View {
        Section {
            ForEach(categories, id: \.name) { category in
                ZStack {
                    CategoryRow(category: category)
                    NavigationLink(destination: CategoryDetailView(category: category, overviewType: .day)) { }.opacity(0)
                }
            }
            .onDelete(perform: onDelete)
        } header: {
            contextCategoryHeader(name: title ?? "Other", timeBudgeted: subtitle)
        }

    }

    private func contextCategoryHeader(name: String, timeBudgeted: String?) -> some View {
        HStack {
            Text(name)
            if let timeBudgeted = timeBudgeted {
                Spacer()
                Text(timeBudgeted)
            }

        }
    }
}

// MARK: - Core Data

extension DayView {

    private func addCategory(name: String) {
        let category = BLCategory(context: managedObjectContext)
        category.name = name
        BLCategory.save(with: managedObjectContext)
    }

    private func addContextCategory(name: String) {
        let contextCategory = ContextCategory(context: managedObjectContext)
        contextCategory.name = name
        ContextCategory.save(with: managedObjectContext)
    }

    private func deleteCategory(at index: Int, contextCategory: ContextCategory? = nil) {
        if let contextCategory = contextCategory,
           let category = contextCategory.categories?.allObjects[index] as? BLCategory {
            self.managedObjectContext.delete(category)
        } else {
            let category = self.categoriesWithNoContextCategory[index]
            self.managedObjectContext.delete(category)
        }
        BLCategory.save(with: managedObjectContext)
    }

    private func deleteContextCategories(_ contextCategories: [ContextCategory]) {
        contextCategories.forEach { managedObjectContext.delete($0) }
        ContextCategory.save(with: managedObjectContext)
    }
}

// MARK: - Extracted Views

struct MoreOptionsMenuButton: View {

    // MARK: - Public Properties

    let categories: [BLCategory]
    let addCategoryAction: () -> Void
    let addContextCategoryAction: () -> Void

    // MARK: - Private Properties
    @Environment(\.managedObjectContext)
    private var managedObjectContext

    // MARK: - Lifecycle

    var body: some View {
        Menu(content: {
            Button("Add Category") {
                addCategoryAction()
            }
            Button("Manage Context Categories") {
                addContextCategoryAction()
            }
            Button("Reset Category Notes") {
                categories.forEach { $0.notes = nil }
                BLCategory.save(with: managedObjectContext)
            }
            Button("Reset Budget") {
                categories.forEach { $0.dailyBudgetDuration = 0 }
                BLCategory.save(with: managedObjectContext)
            }
        }, label: {
            Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44)
        })
    }
}

// MARK: - Preview

struct DayView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let dataStore = ObservedObject(initialValue: DataStore(managedObjectContext: context))
        return Group {
            DayView()
                .environment(\.managedObjectContext, context)
                .environment(\.dataStore, dataStore)
            DayView().environment(\.managedObjectContext, context)
                .environment(\.managedObjectContext, context)
                .environment(\.dataStore, dataStore)
                .environment(\.colorScheme, .dark)
        }
    }
}
