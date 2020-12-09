//
//  MonthView.swift
//  Busyless
//
//  Created by Derrick Showers on 11/2/20.
//  Copyright © 2020 Derrick Showers. All rights reserved.
//

import SwiftUI
import BusylessDataLayer

struct MonthView: View {

    // MARK: - Private Properties

    @Environment(\.managedObjectContext)
    private var managedObjectContext

    @Environment(\.dataStore)
    private var dataStore

    private var categories: [BLCategory] {
        let categories = dataStore?.wrappedValue.categoryStore.allCategories ?? []
        return categories.sorted { $0.timeSpentThisMonth > $1.timeSpentThisMonth }
    }

    // MARK: - Lifecycle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 5) {
                Text("Where have I been spending my time this month?")
                    .font(.title)
                    .padding(.trailing, 100)
                Text("Tap a category for details")
                    .font(.caption)
                VStack {
                    ForEach(categories, id: \.self) { category in
                        NavigationLink(destination: CategoryDetailView(category: category, overviewType: .month)) {
                            HStack {
                                Text(category.name ?? "Uncategorized")
                                Spacer()
                                Text(category.timeSpentThisMonth.hoursMinutesString).bold()
                            }
                        }
                        if let lastItem = self.categories.last, category != lastItem {
                            Divider()
                        }
                    }
                }
                .foregroundColor(Color(UIColor.label))
                .padding(.vertical, 20)
            }
            .padding(15)
            .frame(maxWidth: .infinity)
            .background(Color.customWhite)
        }
        .background(Color(UIColor.systemGray6))
        .edgesIgnoringSafeArea(.bottom)
        .navigationBarTitle("This Month")
    }
}

struct MonthView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        let dataStore = ObservedObject(initialValue: DataStore(managedObjectContext: context))
        return Group {
            MonthView()
                .environment(\.managedObjectContext, context)
                .environment(\.dataStore, dataStore)
            MonthView()
                .environment(\.managedObjectContext, context)
                .environment(\.dataStore, dataStore)
                .environment(\.colorScheme, .dark)
        }
    }
}
