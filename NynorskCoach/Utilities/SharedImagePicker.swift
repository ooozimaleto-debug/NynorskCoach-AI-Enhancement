//
//  SharedImagePicker.swift
//  NynorskCoach
//

import SwiftUI
import PhotosUI

// Для камеры (UIImagePickerController только для камеры - это ок!)
struct CameraPickerView: UIViewControllerRepresentable {
    var onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onImagePicked(img)
            }
            picker.dismiss(animated: true)
        }
    }
}

// Для галереи (PhotosPicker - современный!)
struct GalleryPickerView: View {
    var onImagePicked: (UIImage) -> Void
    @State private var selectedItem: PhotosPickerItem?
    
    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            Color.clear
        }
        .onChange(of: selectedItem) { _, newValue in
            Task {
                if let data = try await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onImagePicked(image)
                }
            }
        }
    }
}

// Универсальный picker - используется везде
struct ImagePickerView: UIViewControllerRepresentable {
    enum SourceType { case camera, photoLibrary }
    
    var sourceType: SourceType
    var onImagePicked: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType == .camera ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage {
                parent.onImagePicked(img)
            }
            picker.dismiss(animated: true)
        }
    }
}
