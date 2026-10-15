import AppKit
import ImageIO
import SwiftUI

@MainActor
final class WallpaperPickerModel: ObservableObject {
    @Published private(set) var wallpapers: [URL] = []
    @Published private(set) var currentWallpapers: Set<URL> = []
    @Published var selection = 0

    func reload() {
        let directory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kipr/wallpapers")
        wallpapers = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))?
            .filter { ["jpg", "jpeg", "png", "heic", "webp"].contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending } ?? []
        currentWallpapers = Set(NSScreen.screens.compactMap { NSWorkspace.shared.desktopImageURL(for: $0) })
        selection = min(selection, max(0, wallpapers.count - 1))
    }

    func move(_ offset: Int) {
        guard !wallpapers.isEmpty else { return }
        selection = min(max(selection + offset, 0), wallpapers.count - 1)
    }

    func apply() {
        guard wallpapers.indices.contains(selection) else { return }
        let wallpaper = wallpapers[selection]
        for screen in NSScreen.screens {
            do {
                try NSWorkspace.shared.setDesktopImageURL(wallpaper, for: screen, options: [:])
            } catch {
                NSLog("Could not set wallpaper on screen %@: %@", screen.localizedName, error.localizedDescription)
            }
        }
        currentWallpapers = Set(NSScreen.screens.compactMap { NSWorkspace.shared.desktopImageURL(for: $0) })
    }
}

struct WallpaperPickerView: View {
    @ObservedObject var model: WallpaperPickerModel

    var body: some View {
        HStack(spacing: 16) {
            if model.wallpapers.isEmpty {
                Text("Add images to ~/.kipr/wallpapers").foregroundStyle(.secondary)
            } else {
                HStack(spacing: 10) {
                    ForEach(visibleIndices, id: \.self) { index in
                        let url = model.wallpapers[index]
                        ZStack(alignment: .topTrailing) {
                            WallpaperImage(url: url, maxPixelSize: 600)
                                .frame(width: 260, height: 170)
                                .clipped()
                                .overlay { RoundedRectangle(cornerRadius: 6).stroke(index == model.selection ? Color.orange : .clear, lineWidth: 4) }
                            if model.currentWallpapers.contains(url) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .background(.black.opacity(0.5), in: Circle())
                                    .padding(4)
                            }
                        }
                        .onTapGesture { model.selection = index }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)).padding(1)
    }

    private var visibleIndices: [Int] {
        let count = model.wallpapers.count
        let first = max(0, min(model.selection - 2, count - 5))
        return Array(first..<min(count, first + 5))
    }
}

private struct WallpaperImage: View {
    let url: URL
    let maxPixelSize: Int
    @ObservedObject private var loader: WallpaperImageLoader

    init(url: URL, maxPixelSize: Int) {
        self.url = url
        self.maxPixelSize = maxPixelSize
        _loader = ObservedObject(wrappedValue: WallpaperImageLoader(url: url, maxPixelSize: maxPixelSize))
    }

    var body: some View {
        Group {
            if let image = loader.image {
                Image(nsImage: image).resizable().scaledToFill()
            } else {
                Color.gray.opacity(0.15)
            }
        }
    }
}

@MainActor
private final class WallpaperImageLoader: ObservableObject {
    @Published var image: NSImage?
    private static let cache = NSCache<NSURL, NSImage>()

    init(url: URL, maxPixelSize: Int) {
        if let cached = Self.cache.object(forKey: url as NSURL) {
            image = cached
            return
        }
        Task { [weak self] in
            let loaded = await Task.detached(priority: .userInitiated) {
                Self.load(url: url, maxPixelSize: maxPixelSize)
            }.value
            guard let loaded else { return }
            Self.cache.setObject(loaded, forKey: url as NSURL)
            self?.image = loaded
        }
    }

    nonisolated private static func load(url: URL, maxPixelSize: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(
                source, 0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
                ] as CFDictionary
              ) else { return nil }
        return NSImage(cgImage: image, size: .zero)
    }
}
