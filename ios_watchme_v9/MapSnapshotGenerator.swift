//
//  MapSnapshotGenerator.swift
//  ios_watchme_v9
//
//  地域名から地図スナップショット画像を生成
//

import SwiftUI
import MapKit

class MapSnapshotGenerator {

    /// 地域名から地図スナップショット画像を生成
    /// - Parameters:
    ///   - locationName: 地域名（例：「横浜市」「神奈川県」）
    ///   - size: 画像サイズ
    /// - Returns: 生成された地図のUIImage
    static func generateSnapshot(for locationName: String, size: CGSize) async -> UIImage? {
        // 地域名から座標を取得
        guard let coordinate = await geocode(locationName: locationName) else {
            return nil
        }

        // 地図のスナップショットを生成
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        options.size = size
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)

        do {
            let snapshot = try await snapshotter.start()
            return snapshot.image
        } catch {
            print("地図スナップショット生成エラー: \(error)")
            return nil
        }
    }

    /// 地域名から座標を取得（ジオコーディング）
    /// - Parameter locationName: 地域名
    /// - Returns: 座標（CLLocationCoordinate2D）
    private static func geocode(locationName: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()

        do {
            let placemarks = try await geocoder.geocodeAddressString(locationName)
            return placemarks.first?.location?.coordinate
        } catch {
            print("ジオコーディングエラー: \(error)")
            return nil
        }
    }
}

/// 地図スナップショットを表示するView
struct MapSnapshotView: View {
    let locationName: String
    let height: CGFloat

    @State private var mapImage: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let image = mapImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
            } else if isLoading {
                // ローディング中
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)
                    .overlay(
                        ProgressView()
                    )
            } else {
                // 生成失敗時のフォールバック
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: height)
                    .overlay(
                        VStack {
                            Image(systemName: "map")
                                .font(.system(size: 30))
                                .foregroundColor(.gray)
                            Text(locationName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
        }
        .task {
            await loadMapSnapshot()
        }
    }

    private func loadMapSnapshot() async {
        let screenWidth = UIScreen.main.bounds.width
        let size = CGSize(width: screenWidth, height: height)

        let image = await MapSnapshotGenerator.generateSnapshot(
            for: locationName,
            size: size
        )

        await MainActor.run {
            mapImage = image
            isLoading = false
        }
    }
}
