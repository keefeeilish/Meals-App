import Foundation

struct MealAnalysis: Codable {
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let cholesterol: String
    let isAlcoholic: Bool
    let warnings: [String]?
}
