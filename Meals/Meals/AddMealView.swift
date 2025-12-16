import SwiftUI
import SwiftData
import PhotosUI

struct AddMealView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var modelContext
    
    @State private var selectedImage: UIImage?
    // Camera
    @State private var showingCamera = false
    
    // Gallery (PhotosPicker)
    @State private var selectedPickerItem: PhotosPickerItem?
    
    @State private var isAnalyzing = false
    @State private var analysisResult: MealAnalysis?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 300)
                            .cornerRadius(12)
                            .padding()
                        
                        if isAnalyzing {
                            ProgressView("Analyzing Meal...")
                        } else if let result = analysisResult {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(result.name)
                                    .font(.title2)
                                    .bold()
                                
                                HStack {
                                    MacroView(label: "Calories", value: "\(result.calories)")
                                    MacroView(label: "Protein", value: "\(result.protein)g")
                                    MacroView(label: "Carbs", value: "\(result.carbs)g")
                                    MacroView(label: "Fat", value: "\(result.fat)g")
                                }
                                
                                if !result.cholesterol.isEmpty {
                                    HStack {
                                        Text("Cholesterol:")
                                            .bold()
                                        Text(result.cholesterol)
                                            .foregroundColor(cholesterolColor(result.cholesterol))
                                    }
                                }
                                
                                if result.isAlcoholic {
                                    Text("⚠️ Contains Alcohol")
                                        .foregroundColor(.red)
                                        .bold()
                                }
                                
                                if let warnings = result.warnings, !warnings.isEmpty {
                                    ForEach(warnings, id: \.self) { warning in
                                        Text("Warning: \(warning)")
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        } else {
                            Button("Analyze Meal") {
                                analyzeImage()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    } else {
                        VStack(spacing: 20) {
                            Button(action: {
                                showingCamera = true
                            }) {
                                Label("Take Photo", systemImage: "camera")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            PhotosPicker(selection: $selectedPickerItem, matching: .images) {
                                Label("Choose from Gallery", systemImage: "photo.on.rectangle")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Add Meal")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                if analysisResult != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveMeal()
                        }
                    }
                }
            }
            // Present Camera
            .sheet(isPresented: $showingCamera) {
                ImagePicker(selectedImage: $selectedImage, sourceType: .camera)
            }
            // Handle Validations
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            // Handle Photo Selection
            .onChange(of: selectedPickerItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.selectedImage = image
                        }
                    }
                }
            }
        }
    }
    
    private func analyzeImage() {
        guard let image = selectedImage else { return }
        isAnalyzing = true
        
        Task {
            do {
                let analysis = try await APIService.shared.analyzeImage(image)
                analysisResult = analysis
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isAnalyzing = false
        }
    }
    
    private func saveMeal() {
        guard let result = analysisResult else { return }
        
        let meal = Meal(
            name: result.name,
            calories: result.calories,
            protein: result.protein,
            carbs: result.carbs,
            fat: result.fat,
            cholesterol: result.cholesterol,
            isAlcoholic: result.isAlcoholic,
            warnings: result.warnings ?? []
        )
        
        modelContext.insert(meal)
        presentationMode.wrappedValue.dismiss()
    }
    
    private func cholesterolColor(_ value: String) -> Color {
        switch value.lowercased() {
        case "high": return .red
        case "medium": return .orange
        case "low": return .green
        default: return .primary
        }
    }
}

struct MacroView: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
