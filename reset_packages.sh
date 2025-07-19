#!/bin/bash

echo "Xcodeプロジェクトのパッケージをリセットします..."

# DerivedDataを削除
echo "1. DerivedDataを削除..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Package.resolvedを削除
echo "2. Package.resolvedを削除..."
rm -f ios_watchme_v9.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# ビルドディレクトリを削除
echo "3. ビルドディレクトリを削除..."
rm -rf build/
rm -rf .build/

# Xcodeキャッシュを削除
echo "4. Xcodeキャッシュを削除..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode

# SwiftPMキャッシュを削除
echo "5. SwiftPMキャッシュを削除..."
rm -rf ~/Library/Caches/org.swift.swiftpm

echo "完了しました。"
echo ""
echo "次の手順:"
echo "1. Xcodeを完全に終了してください"
echo "2. Xcodeを再起動してプロジェクトを開いてください"
echo "3. File → Packages → Reset Package Caches を選択してください"
echo "4. File → Packages → Resolve Package Versions を選択してください"
echo "5. Product → Clean Build Folder (Shift+Cmd+K) を実行してください"
echo "6. Product → Build (Cmd+B) を実行してください"