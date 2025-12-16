import Foundation
import SwiftData

@Model
final class Meal {
    var name: String
    var timestamp: Date
    var calories: Int
    var protein: Int
    var carbs: Int
    var fat: Int
    var cholesterol: String // e.g., "High", "Low", "Medium"
    var isAlcoholic: Bool
    var warnings: [String]
    
    init(name: String, timestamp: Date = Date(), calories: Int, protein: Int, carbs: Int, fat: Int, cholesterol: String, isAlcoholic: Bool, warnings: [String]) {
        self.name = name
        self.timestamp = timestamp
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.cholesterol = cholesterol
        self.isAlcoholic = isAlcoholic
        self.warnings = warnings
    }
}
