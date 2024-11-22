//
//  ContentView.swift
//  InstaFilter
//
//  Created by Anushka on 22/11/2024.
//

//
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftUI
import StoreKit

struct ContentView: View {
    @State private var processedImage: Image?
    @State private var selectedItem: PhotosPickerItem?
    @State private var filterIntensity = 0.5
    @State private var showingFilters = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    @AppStorage("filterCount") private var filterCount = 0
    @Environment(\.requestReview) private var requestReview: RequestReviewAction
    
    @State private var currentFilter: CIFilter = CIFilter.sepiaTone()
    private let context = CIContext()
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                PhotosPicker(selection: $selectedItem,
                           matching: .images,
                           photoLibrary: .shared()) {
                    if let processedImage {
                        processedImage
                            .resizable()
                            .scaledToFit()
                            .frame(minHeight: 200, maxHeight: UIScreen.main.bounds.height * 0.6)
                    } else {
                        ContentUnavailableView("No Picture",
                            systemImage: "photo.badge.plus",
                            description: Text("Tap to select a photo")
                        )
                    }
                }
                .onChange(of: selectedItem) { oldValue, newValue in
                    Task {
                        await loadImage()
                    }
                }
                
                Spacer()
                
                // Slider for intensity adjustment
                HStack {
                    Text("Intensity")
                        .frame(width: 80, alignment: .leading)
                    Slider(value: $filterIntensity, in: 0...1)
                        .onChange(of: filterIntensity) { oldValue, newValue in
                            applyProcessing()
                        }
                }
                .padding(.vertical)
                .disabled(processedImage == nil)
                
                HStack {
                    Button("Change Filter") {
                        showingFilters = true
                    }
                    .disabled(processedImage == nil)
                    
                    if let processedImage {
                        ShareLink(item: processedImage,
                                preview: SharePreview("Instafilter Image", image: processedImage))
                    }
                    
                    Spacer()
                }
            }
            .padding([.horizontal, .bottom])
            .navigationTitle("Instafilter")
            .confirmationDialog("Select a filter", isPresented: $showingFilters) {
                Group {
                    Button("Crystallize") { setFilter(CIFilter.crystallize()) }
                    Button("Edges") { setFilter(CIFilter.edges()) }
                    Button("Gaussian Blur") { setFilter(CIFilter.gaussianBlur()) }
                    Button("Pixellate") { setFilter(CIFilter.pixellate()) }
                    Button("Sepia Tone") { setFilter(CIFilter.sepiaTone()) }
                    Button("Unsharp Mask") { setFilter(CIFilter.unsharpMask()) }
                    Button("Vignette") { setFilter(CIFilter.vignette()) }
                    Button("Cancel", role: .cancel) { }
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    func loadImage() async {
        do {
            guard let selectedItem else { return }
            guard let imageData = try await selectedItem.loadTransferable(type: Data.self) else {
                throw PhotoError.failedToLoadImage
            }
            guard let inputImage = UIImage(data: imageData) else {
                throw PhotoError.invalidImageData
            }
            
            let beginImage = CIImage(image: inputImage)
            currentFilter.setValue(beginImage, forKey: kCIInputImageKey)
            applyProcessing()
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
    
    func applyProcessing() {
        let inputKeys = currentFilter.inputKeys
        
        if inputKeys.contains(kCIInputIntensityKey) {
            currentFilter.setValue(filterIntensity, forKey: kCIInputIntensityKey)
        }
        if inputKeys.contains(kCIInputRadiusKey) {
            currentFilter.setValue(filterIntensity * 200, forKey: kCIInputRadiusKey)
        }
        if inputKeys.contains(kCIInputScaleKey) {
            currentFilter.setValue(filterIntensity * 10, forKey: kCIInputScaleKey)
        }
        
        guard let outputImage = currentFilter.outputImage else {
            errorMessage = "Failed to process image"
            showingErrorAlert = true
            return
        }
        
        guard let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            errorMessage = "Failed to create final image"
            showingErrorAlert = true
            return
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        processedImage = Image(uiImage: uiImage)
    }
    
    @MainActor func setFilter(_ filter: CIFilter) {
        currentFilter = filter
        Task {
            await loadImage()
        }
        filterCount += 1
        
        if filterCount >= 20 {
            requestReview()
        }
    }
}

enum PhotoError: LocalizedError {
    case failedToLoadImage
    case invalidImageData
    
    var errorDescription: String? {
        switch self {
        case .failedToLoadImage:
            return "Failed to load the selected image"
        case .invalidImageData:
            return "The selected image data is invalid"
        }
    }
}

#Preview {
    ContentView()
}
