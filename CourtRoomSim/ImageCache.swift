import UIKit

struct ImageCache {
    // Returns the path to the caches directory.
    static func cacheDirectory() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }
    
    // Constructs a unique file URL using the case's UUID and the character's name.
    static func imageURL(forCaseId caseId: UUID, characterName: String) -> URL? {
        guard let cacheDir = cacheDirectory() else { return nil }
        // Make a safe file name by replacing spaces with underscores.
        let safeName = characterName.replacingOccurrences(of: " ", with: "_")
        return cacheDir.appendingPathComponent("\(caseId.uuidString)_\(safeName).jpg")
    }
    
    // Loads the image from disk if it exists.
    static func loadImage(caseId: UUID, characterName: String) -> UIImage? {
        guard let url = imageURL(forCaseId: caseId, characterName: characterName) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    
    // Saves the image as JPEG data to disk.
    static func saveImage(_ image: UIImage, caseId: UUID, characterName: String) {
        guard let url = imageURL(forCaseId: caseId, characterName: characterName),
              let data = image.jpegData(compressionQuality: 0.8)
        else { return }
        do {
            try data.write(to: url)
        } catch {
            print("Failed to save image to cache: \(error)")
        }
    }
}
