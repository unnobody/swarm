#!/bin/bash

# Secure Mesh Messenger - Build Script for Android APK
# Этот скрипт компилирует Rust core для всех архитектур Android и собирает APK.

set -e # Остановиться при ошибке

echo "🚀 Начало сборки Secure Mesh Messenger..."

# 1. Проверка зависимостей
echo "🔍 Проверка зависимостей..."
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter не найден. Установите Flutter SDK."
    exit 1
fi

if ! command -v cargo &> /dev/null; then
    echo "❌ Cargo (Rust) не найден. Установите Rust."
    exit 1
fi

# 2. Установка target'ов для Rust (если не установлены)
echo "🦀 Настройка Rust targets для Android..."
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add x86_64-linux-android
rustup target add i686-linux-android

# 3. Компиляция Rust библиотек
echo "⚙️ Компиляция Rust core (mesh_core)..."
cd mesh_core

# ARM64 (Современные устройства)
echo "   📱 Сборка для arm64-v8a..."
cargo build --release --target aarch64-linux-android

# ARMv7 (Старые устройства)
echo "   📱 Сборка для armeabi-v7a..."
cargo build --release --target armv7-linux-androideabi

# x86_64 (Эмуляторы)
echo "   💻 Сборка для x86_64..."
cargo build --release --target x86_64-linux-android

# x86 (Старые эмуляторы)
echo "   💻 Сборка для x86..."
cargo build --release --target i686-linux-android

cd ..

# 4. Копирование библиотек в Flutter проект
echo "📦 Копирование .so файлов в Flutter проект..."

# Создаем структуру папок для JNI
mkdir -p mesh_app/android/app/src/main/jniLibs/arm64-v8a
mkdir -p mesh_app/android/app/src/main/jniLibs/armeabi-v7a
mkdir -p mesh_app/android/app/src/main/jniLibs/x86_64
mkdir -p mesh_app/android/app/src/main/jniLibs/x86

cp mesh_core/target/aarch64-linux-android/release/libmesh_core.so mesh_app/android/app/src/main/jniLibs/arm64-v8a/libmesh_core.so
cp mesh_core/target/armv7-linux-androideabi/release/libmesh_core.so mesh_app/android/app/src/main/jniLibs/armeabi-v7a/libmesh_core.so
cp mesh_core/target/x86_64-linux-android/release/libmesh_core.so mesh_app/android/app/src/main/jniLibs/x86_64/libmesh_core.so
cp mesh_core/target/i686-linux-android/release/libmesh_core.so mesh_app/android/app/src/main/jniLibs/x86/libmesh_core.so

echo "✅ Библиотеки скопированы."

# 5. Генерация FFI кода (на всякий случай)
echo "🌉 Генерация Flutter Rust Bridge кода..."
cd mesh_app
# Если flutter_rust_bridge_codegen не установлен, раскомментируйте строку ниже:
# cargo install flutter_rust_bridge_codegen
flutter_rust_bridge_codegen generate --rust-input ../mesh_core/src/lib.rs --dart-output lib/bridges/mesh_core_bridge.frb.dart --c-output src/bridge.h || echo "⚠️ Предупреждение: Возможно, код уже сгенерирован или требуется установка codegen."

# 6. Очистка и получение зависимостей Flutter
echo "🧹 Очистка и получение зависимостей..."
flutter clean
flutter pub get

# 7. Сборка APK
echo "🏗️ Сборка Release APK..."
# Используем --no-tree-shake-icons для отладки, уберите для продакшена если нужно
flutter build apk --release --split-per-abi

echo ""
echo "🎉 Сборка завершена успешно!"
echo "📍 APK файлы находятся в:"
echo "   build/app/outputs/flutter-apk/"
echo ""
echo "Для установки на устройство выполните:"
echo "   flutter install"
