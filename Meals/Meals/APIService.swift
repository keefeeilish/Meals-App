import Foundation
import UIKit

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case parsingError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL could not be constructed. Check your API Key characters."
        case .invalidResponse:
            return "The server returned an invalid response."
        case .parsingError:
            return "Failed to read the AI response. It might be malformed."
        case .serverError(let message):
            return message
        }
    }
}

class APIService {
    static let shared = APIService()
    private var apiKey: String {
        // Try to read efficiently
        if let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
           let key = dict["API_KEY"] as? String {
            return key.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }
        return "" // Return empty to be caught by guard
    }
    
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent"
    
    func analyzeImage(_ image: UIImage) async throws -> MealAnalysis {
        // 1. Resize & Compress Image (Crucial for API Limits)
        // Downscale to max 1024px to prevent "Overloaded" size errors
        let resizedImage = ResizeImage(image: image, targetSize: CGSize(width: 1024, height: 1024))
        
        guard let imageData = resizedImage.jpegData(compressionQuality: 0.7) else { // Lower quality slightly
            throw APIError.serverError("Failed to process image.")
        }
        
        // 2. Check API Key
        let keyToUse = apiKey
        if keyToUse.isEmpty || keyToUse == "YOUR_API_KEY_HERE" {
            throw APIError.serverError("Secrets.plist is missing or API_KEY is invalid.")
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // 3. Encode Key
        guard let encodedKey = keyToUse.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw APIError.serverError("Failed to encode API Key.")
        }
        
        // 4. Construct URL
        let urlString = "\(endpoint)?key=\(encodedKey)"
        guard let url = URL(string: urlString) else {
            throw APIError.serverError("Failed to create URL from: \(endpoint)")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Exact Prompt for JSON Mode
        let promptText = """
        Analyze this food image. Provide a JSON response with the following structure:
        {
            "name": "Meal Name",
            "calories": 0,
            "protein": 0,
            "carbs": 0,
            "fat": 0,
            "cholesterol": "Low/Medium/High",
            "isAlcoholic": false,
            "warnings": ["Array", "of", "health", "warnings"]
        }
        
        - 'calories', 'protein', 'carbs', 'fat' should be Integers.
        - 'cholesterol' should be exactly "High", "Medium", or "Low".
        - 'warnings' should include things like "High Cholesterol", "Contains Alcohol", "Allergen: Peanuts", etc. if applicable.
        - 'isAlcoholic' is true if the image contains alcoholic beverages.
        """
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": promptText],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "response_mime_type": "application/json"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        return try await performRequestWithRetry(request: request)
    }
    
    private func performRequestWithRetry(request: URLRequest, attempt: Int = 1) async throws -> MealAnalysis {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            // Check for 503 Overloaded -> RETRY
            if httpResponse.statusCode == 503 && attempt <= 3 {
                print("DEBUG: 503 Overloaded. Retrying (Attempt \(attempt)/3)...")
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000) // Sleep 2s
                return try await performRequestWithRetry(request: request, attempt: attempt + 1)
            }
            
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Error"
            
            // Check for 404 Model Not Found
            if httpResponse.statusCode == 404 {
                print("DEBUG: Model 404. Attempting to list available models...")
                let availableModels = try await listModels()
                throw APIError.serverError("Model Not Found. Available: \(availableModels)")
            }
            
            throw APIError.serverError("API Error (\(httpResponse.statusCode)): \(errorMsg)")
        }
        
        // Parse Gemini Response Structure
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard let jsonText = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw APIError.parsingError
        }
        
        guard let jsonData = jsonText.data(using: .utf8) else { throw APIError.parsingError }
        
        return try JSONDecoder().decode(MealAnalysis.self, from: jsonData)
    }
    
    private func listModels() async throws -> String {
        let listUrlString = "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)"
        guard let url = URL(string: listUrlString) else { return "Could not list models" }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        struct ModelListResponse: Codable {
            let models: [ModelInfo]
        }
        struct ModelInfo: Codable {
            let name: String
            let supportedGenerationMethods: [String]
        }
        
        if let list = try? JSONDecoder().decode(ModelListResponse.self, from: data) {
            // Filter for vision models
            let visionModels = list.models.filter { $0.supportedGenerationMethods.contains("generateContent") }
            let names = visionModels.prefix(3).map { $0.name.replacingOccurrences(of: "models/", with: "") }
            return names.joined(separator: ", ")
        }
        return "No accessible models found."
    }
}

// Private helper structs for decoding Gemini API response
private struct GeminiResponse: Codable {
    let candidates: [Candidate]
}

private struct Candidate: Codable {
    let content: Content
}

private struct Content: Codable {
    let parts: [Part]
}

private struct Part: Codable {
    let text: String
}
