import SwiftUI
import SafariServices // Добавлено для работы браузера

#if os(macOS)
    import AppKit
    typealias PlatformImage = NSImage
#else
    import UIKit
    typealias PlatformImage = UIImage
#endif

// Расширение для конвертации данных в картинку
extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
            self.init(nsImage: platformImage)
        #else
            self.init(uiImage: platformImage)
        #endif
    }
}

// Хелпер для сжатия (на Mac и iOS по-разному)
func compressImage(data: Data) -> Data? {
    #if os(macOS)
        guard let image = NSImage(data: data),
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.5])
    #else
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: 0.5)
    #endif
}

// MARK: - УНИВЕРСАЛЬНЫЙ БРАУЗЕР
// Используется в GrammarView, ReaderView и SettingsView
#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true // Пытаемся открыть режим чтения сразу
        return SFSafariViewController(url: url, configuration: config)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif
