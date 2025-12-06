//
//  ImageCacheManager.swift
//  ios_watchme_v9
//
//  Centralized image caching service for avatar images
//  Provides memory cache and automatic cache eviction
//

import SwiftUI
import UIKit

// Image cache manager with NSCache
class ImageCacheManager: ObservableObject {
    static let shared = ImageCacheManager()

    // Memory cache for downloaded images
    private let cache = NSCache<NSString, UIImage>()

    // Track active download tasks to prevent duplicate downloads
    private var activeTasks: [String: Task<UIImage?, Never>] = [:]
    private let taskLock = NSLock()

    private init() {
        // Configure cache limits
        cache.countLimit = 100  // Max 100 images
        cache.totalCostLimit = 50 * 1024 * 1024  // Max 50MB
    }

    // Get cached image or download
    func getImage(for url: URL) async -> UIImage? {
        let cacheKey = url.absoluteString as NSString

        // Check memory cache first
        if let cachedImage = cache.object(forKey: cacheKey) {
            #if DEBUG
            print("🖼️ [ImageCache] Cache hit: \(url.lastPathComponent)")
            #endif
            return cachedImage
        }

        // Check if download is already in progress
        taskLock.lock()
        if let existingTask = activeTasks[url.absoluteString] {
            taskLock.unlock()
            #if DEBUG
            print("🔄 [ImageCache] Reusing active download: \(url.lastPathComponent)")
            #endif
            return await existingTask.value
        }

        // Create new download task
        let downloadTask = Task<UIImage?, Never> {
            await downloadImage(from: url)
        }

        activeTasks[url.absoluteString] = downloadTask
        taskLock.unlock()

        // Wait for download to complete
        let image = await downloadTask.value

        // Clean up task
        taskLock.lock()
        activeTasks.removeValue(forKey: url.absoluteString)
        taskLock.unlock()

        return image
    }

    // Download image from URL
    private func downloadImage(from url: URL) async -> UIImage? {
        #if DEBUG
        print("⬇️ [ImageCache] Downloading: \(url.lastPathComponent)")
        #endif

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            // Validate HTTP response
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                #if DEBUG
                print("❌ [ImageCache] Invalid response for: \(url.lastPathComponent)")
                #endif
                return nil
            }

            // Decode image
            guard let image = UIImage(data: data) else {
                #if DEBUG
                print("❌ [ImageCache] Failed to decode image: \(url.lastPathComponent)")
                #endif
                return nil
            }

            // Cache the image (cost = estimated memory size in bytes)
            let cost = data.count
            let cacheKey = url.absoluteString as NSString
            cache.setObject(image, forKey: cacheKey, cost: cost)

            #if DEBUG
            print("✅ [ImageCache] Downloaded and cached: \(url.lastPathComponent) (\(cost / 1024)KB)")
            #endif

            return image
        } catch {
            #if DEBUG
            print("❌ [ImageCache] Download error for \(url.lastPathComponent): \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // Clear cache manually
    func clearCache() {
        cache.removeAllObjects()
        #if DEBUG
        print("🗑️ [ImageCache] Cache cleared")
        #endif
    }

    // Remove specific image from cache
    func removeImage(for url: URL) {
        let cacheKey = url.absoluteString as NSString
        cache.removeObject(forKey: cacheKey)
        #if DEBUG
        print("🗑️ [ImageCache] Removed from cache: \(url.lastPathComponent)")
        #endif
    }
}
