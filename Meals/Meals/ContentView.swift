import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Meal.timestamp, order: .reverse) private var meals: [Meal]
    
    @State private var showingAddMeal = false

    var body: some View {
        NavigationView {
            List {
                ForEach(groupedMeals, id: \.key) { date, mealsForDate in
                    Section(header: Text(date, style: .date)) {
                        ForEach(mealsForDate) { meal in
                            MealRow(meal: meal)
                        }
                        .onDelete { indexSet in
                            deleteMeals(offsets: indexSet, from: mealsForDate)
                        }
                    }
                }
            }
            .navigationTitle("Food Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddMeal = true }) {
                        Label("Add Meal", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddMeal) {
                AddMealView()
            }
        }
    }
    
    private var groupedMeals: [(key: Date, value: [Meal])] {
        let grouped = Dictionary(grouping: meals) { meal in
            Calendar.current.startOfDay(for: meal.timestamp)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func deleteMeals(offsets: IndexSet, from sectionMeals: [Meal]) {
        withAnimation {
            for index in offsets {
                modelContext.delete(sectionMeals[index])
            }
        }
    }
}

struct MealRow: View {
    let meal: Meal
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text(meal.name)
                    .font(.headline)
                Spacer()
                Text("\(meal.calories) kcal")
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 12) {
                Label("\(meal.protein)p", systemImage: "circle.fill").foregroundColor(.red).font(.caption)
                Label("\(meal.carbs)c", systemImage: "circle.fill").foregroundColor(.green).font(.caption)
                Label("\(meal.fat)f", systemImage: "circle.fill").foregroundColor(.yellow).font(.caption)
                
                if meal.isAlcoholic {
                    Text("🍷").font(.caption)
                }
                
                if !meal.warnings.isEmpty {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Meal.self, inMemory: true)
}
