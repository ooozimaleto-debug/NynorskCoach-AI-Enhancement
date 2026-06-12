import SwiftUI
import Vision
import VisionKit

@MainActor
@Observable
class UnifiedVisionViewModel {
    // MARK: - State Properties
    var mode: VisionMode = .ocr
    var image: UIImage?
    var showCamera = false
    var showGallery = false
    var isProcessing = false
    var errorMessage: String?
    
    // OCR Mode
    var recognizedWords: [RecognizedWord] = []
    var selectedWord: ScannerSelectedWord?
    
    // Describe Mode
    var userDescription = ""
    var aiFeedback: ChatResponse?
    var showFeedback = false
    
    // Identify Mode
    var objectResult: ObjectResult?
    
    // MARK: - Actions
    
    func resetState() {
        self.image = nil
        self.recognizedWords = []
        self.userDescription = ""
        self.aiFeedback = nil
        self.objectResult = nil
        self.errorMessage = nil
        self.showFeedback = false
    }
    
    func processImage(_ uiImage: UIImage) {
        // Fix orientation first
        guard let fixedImage = uiImage.fixedOrientation() else {
            errorMessage = "Некорректное изображение"
            return
        }
        
        self.image = fixedImage
        self.errorMessage = nil
        
        switch mode {
        case .ocr:
            performOCR(fixedImage)
        case .describe:
            // Wait for user input
            self.isProcessing = false
        case .identify:
            identifyObject(fixedImage)
        }
    }
    
    // MARK: - OCR Mode
    
    private func performOCR(_ img: UIImage) {
        guard let cgImage = img.cgImage else {
            errorMessage = "Ошибка обработки изображения"
            isProcessing = false
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                let words = try await recognizeText(from: cgImage)
                if words.isEmpty {
                    self.errorMessage = "Текст не найден"
                }
                self.recognizedWords = words
                self.isProcessing = false
            } catch {
                self.errorMessage = "Ошибка распознавания текста"
                self.isProcessing = false
            }
        }
    }
    
    private nonisolated func recognizeText(from cgImage: CGImage) async throws -> [RecognizedWord] {
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["no", "en"]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])
            
            guard let observations = request.results, !observations.isEmpty else {
                throw VisionError.noTextFound
            }
            
            return observations.compactMap { obs in
                guard let candidate = obs.topCandidates(1).first else { return nil }
                return RecognizedWord(text: candidate.string, boundingBox: obs.boundingBox)
            }
        }.value
    }
    
    // MARK: - Describe Mode
    
    func checkUserDescription(mentorID: String) {
        guard let img = image, let imgData = img.jpegData(compressionQuality: 0.5) else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let mentor = Mentor(rawValue: mentorID) ?? .freya
                let response = try await OpenAIService.shared.checkImageDescription(
                    imageData: imgData,
                    userDescription: userDescription,
                    mentor: mentor,
                    rank: .oppdagar
                )
                
                self.aiFeedback = response
                self.isProcessing = false
                self.showFeedback = true
                
            } catch {
                self.errorMessage = "Ошибка связи с AI"
                self.isProcessing = false
            }
        }
    }
    
    // MARK: - Identify Mode
    
    private func identifyObject(_ img: UIImage) {
        guard let imgData = img.jpegData(compressionQuality: 0.5) else {
            errorMessage = "Ошибка обработки изображения"
            return
        }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // Прямой вызов нового метода, возвращающего ObjectResult
                let result = try await OpenAIService.shared.identifyImage(imageData: imgData)
                
                self.objectResult = result
                self.isProcessing = false
                AudioManager.shared.play(.success)
                
            } catch {
                print("❌ Identify failed: \(error)")
                self.errorMessage = "Ошибка связи с AI"
                self.isProcessing = false
                AudioManager.shared.play(.error)
            }
        }
    }
}
