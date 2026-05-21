# 📔 Logbook App - Praktikum Penerapan Prinsip SRP

## 📖 Deskripsi Proyek

**Logbook App** adalah aplikasi mobile yang dibangun menggunakan Flutter dengan tujuan pendidikan untuk mendemonstrasikan penerapan **Single Responsibility Principle (SRP)** - salah satu prinsip SOLID dalam pengembangan perangkat lunak yang profesional.

Aplikasi ini memungkinkan pengguna untuk:
- ✅ Mencatat logbook dengan kategori dan timestamp
- ✅ Mengambil foto menggunakan kamera perangkat
- ✅ Menyimpan data secara offline menggunakan Hive
- ✅ Sinkronisasi data ke MongoDB (ketika online)
- ✅ Menampilkan riwayat logbook dengan format yang rapi

### 🎯 Tujuan Pembelajaran

Proyek ini dirancang untuk membantu developer memahami bagaimana menerapkan prinsip SRP dalam praktik, sehingga kode menjadi:
- Lebih mudah dipelihara dan dikembangkan
- Lebih mudah diuji secara independen
- Lebih mudah dipahami oleh tim development
- Lebih reusable dan fleksibel

---

## 🖥️ Prasyarat Sistem

### Kebutuhan Minimum

| Komponen | Versi | Keterangan |
|----------|-------|-----------|
| **Dart SDK** | ≥ 3.0.0 | Bahasa pemrograman untuk Flutter |
| **Flutter SDK** | ≥ 3.0.0 | Framework untuk pembuatan aplikasi mobile |
| **RAM** | ≥ 4 GB | Untuk emulator dan development tools |
| **Disk Space** | ≥ 10 GB | Untuk SDK dan project |
| **Git** | Latest | Untuk version control |

### Platform Target

Aplikasi ini mendukung development dan deployment di platform berikut:

| Platform | Status | Syarat Tambahan |
|----------|--------|-----------------|
| **Android** | ✅ Fully Supported | Android Studio / Gradle |
| **iOS** | ✅ Fully Supported | Xcode 14+ (macOS 12+) |
| **Web** | ✅ Fully Supported | Browser modern |
| **Linux** | ✅ Fully Supported | CMake 3.10+ |
| **Windows** | ⚠️ Dapat dijalankan | Visual Studio Build Tools |
| **macOS** | ✅ Fully Supported | Xcode Command Line Tools |

---

## 🛠️ Instalasi Dependencies dan Tools

### 1️⃣ Instalasi Flutter SDK

#### Di macOS/Linux:

```bash
# Download Flutter SDK
cd ~/development
git clone https://github.com/flutter/flutter.git -b stable

# Tambahkan Flutter ke PATH
export PATH="$PATH:`pwd`/flutter/bin"

# Verifikasi instalasi
flutter doctor
```

#### Di Windows:

1. Download Flutter SDK dari [https://flutter.dev/docs/get-started/install/windows](https://flutter.dev/docs/get-started/install/windows)
2. Extract ke folder tanpa spasi, contoh: `C:\flutter`
3. Tambahkan `C:\flutter\bin` ke Environment Variables PATH
4. Buka terminal baru dan jalankan:
   ```bash
   flutter doctor
   ```

### 2️⃣ Setup Development Environment

#### Android Development

```bash
# Install Android Studio
# Buka Android Studio dan install:
# - Android SDK
# - Android Emulator
# - Android SDK Platform Tools

# Atau gunakan command line untuk Linux/macOS:
flutter pub global activate fvm  # Opsional: untuk manage Flutter versions

# Setup Android emulator
android create avd --name logbook_emulator --target android-33
```

#### iOS Development (Hanya macOS)

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Install CocoaPods (dependency manager untuk iOS)
sudo gem install cocoapods

# Verify setup
flutter doctor
```

#### Linux Development

```bash
# Install dependencies
sudo apt-get install -y \
    build-essential \
    libssl-dev \
    pkg-config \
    cmake \
    ninja-build \
    clang \
    libgtk-3-dev

# Jika menggunakan Fedora/RHEL:
sudo dnf install -y \
    gcc g++ make \
    openssl-devel \
    pkg-config \
    cmake \
    ninja-build \
    clang \
    gtk3-devel
```

### 3️⃣ Verifikasi Instalasi

```bash
# Check Flutter dan Dart version
flutter --version
dart --version

# Check development environment
flutter doctor
```

Pastikan hasil `flutter doctor` menunjukkan status ✓ untuk Android SDK, Flutter SDK, dan platform yang akan digunakan.

---

## 📋 Struktur Proyek

```
lib/
├── main.dart                      # Entry point aplikasi
├── features/                      # Fitur utama aplikasi
│   ├── auth/                     # Halaman Authentikasi
|   ├── vision/                   # Halaman PCD
|   ├── onboarding/               # Halaman onboarding
│   └── logbook/                  # Fitur utama logbook
│       ├── models/               # Data models (LogModel, LogCategory)
│       ├── services/             # Business logic layer
│       └── views/                # UI Layer
├── services/                      # Layanan global
│   ├── storage_service.dart      # Hive local storage
│   └── connectivity_service.dart # Network connectivity
├── helpers/                       # Helper functions & utilities
└── assets/                        # Images dan resources
    └── images/
```

---

## 🚀 Setup Environment dan Instalasi

### Langkah 1: Clone Repository

```bash
# Navigasi ke folder tempat Anda ingin menyimpan proyek
cd ~/Projects

# Clone repository (jika menggunakan Git)
# git clone <URL_REPOSITORY> Counter_Log
# atau
# Jika sudah ada folder, navigasi ke dalamnya
cd Counter_Log
```

### Langkah 2: Install Dependencies Flutter

```bash
# Update pubspec.yaml dan download packages
flutter pub get

# Atau gunakan clean cache jika ada masalah
flutter clean
flutter pub get
```

### Langkah 3: Generate Code (Jika Diperlukan)

Proyek ini menggunakan code generation untuk Hive dan Build Runner:

```bash
# Generate code untuk Hive adapters dan dependency injection
flutter pub run build_runner build

# Atau jika ada perubahan di models, gunakan watch mode:
flutter pub run build_runner watch
```

### Langkah 4: Konfigurasi Environment Variables

```bash
# Copy template .env file
cp .env.example .env

# Edit .env sesuai dengan konfigurasi Anda
# Contoh isi .env:
MONGO_DB_URL=mongodb+srv://username:password@cluster.mongodb.net/logbook_db
API_BASE_URL=https://api.example.com
```

### Langkah 5: Setup Platform Spesifik (Opsional)

#### Android:
```bash
cd android
./gradlew clean
cd ..
```

#### iOS (macOS only):
```bash
cd ios
pod install
cd ..
```

---

## ▶️ Menjalankan Aplikasi

### Perintah Dasar

```bash
# List available devices
flutter devices

# Run dengan device spesifik
flutter run

# Run di emulator Android tertentu
flutter run -d emulator-5554

# Run di iOS simulator (macOS only)
flutter run -d "iPhone 15"

# Run di web
flutter run -d chrome

# Run dengan debug print yang lebih detail
flutter run -v

# Run dengan mode release (optimized)
flutter run --release

# Run dengan mode profile (untuk performance profiling)
flutter run --profile
```

### Development dengan Hot Reload

Saat menjalankan aplikasi, Anda dapat menggunakan hot reload untuk pengembangan yang lebih cepat:

```bash
# Hot reload: Reload code changes tanpa restart app
# Tekan 'r' dalam terminal

# Hot restart: Restart app (state akan direset)
# Tekan 'R' dalam terminal

# Quit
# Tekan 'q' dalam terminal
```

### Menjalankan Tests

```bash
# Jalankan semua unit tests
flutter test

# Jalankan test spesifik
flutter test test/counter_test.dart

# Jalankan tests dengan coverage
flutter test --coverage

# Lihat coverage report (install lcov terlebih dahulu)
lcov -l coverage/lcov.info
```

---

## 🧪 Troubleshooting - Solusi Error Umum

### 1. ❌ Error: "No devices found"

**Gejala:**
```
Error: No devices found
```

**Solusi:**

```bash
# Check devices yang tersedia
flutter devices

# Jika belum ada Android Emulator, buat baru:
flutter emulators --create --name logbook_test

# Start emulator
flutter emulators --launch logbook_test

# Atau untuk iOS (macOS):
open -a Simulator

# Verifikasi devices sudah terdeteksi
flutter devices
```

---

### 2. ❌ Error: "Failed to find Android SDK"

**Gejala:**
```
Error: Unable to locate Android SDK.
```

**Solusi:**

```bash
# Set ANDROID_HOME environment variable
# Linux/macOS:
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools/bin

# Tambahkan ke ~/.bashrc atau ~/.zshrc untuk permanent
echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.zshrc
source ~/.zshrc

# Verify setup
flutter doctor

# Atau accept Android licenses
flutter doctor --android-licenses
```

---

### 3. ❌ Error: "pub get failed" atau Dependency Conflict

**Gejala:**
```
Because example depends on foo ^1.0.0 and example depends on bar ^2.0.0,
and bar depends on foo ^0.9.0, foo ^1.0.0 is forbidden.
```

**Solusi:**

```bash
# Clear cache lengkap
flutter clean
rm pubspec.lock
rm -rf build/

# Download dependencies baru
flutter pub get

# Update packages ke versi terbaru
flutter pub upgrade

# Atau jika ada package tertentu bermasalah:
flutter pub cache clean
flutter pub get
```

---

### 4. ❌ Error: "Gradle build failed" (Android)

**Gejala:**
```
FAILURE: Build failed with an exception.
* What went wrong:
Execution failed for task ':app:compileDebugKotlin'.
```

**Solusi:**

```bash
# Clean Android build
cd android
./gradlew clean
cd ..

# Rebuild
flutter clean
flutter pub get
flutter run

# Jika masih error, update Gradle:
cd android
# Edit build.gradle, update gradle version
./gradlew wrapper --gradle-version=8.x
cd ..
```

---

### 5. ❌ Error: "CocoaPods dependency conflict" (iOS)

**Gejala:**
```
Error: CocoaPods not installed or not in valid state.
```

**Solusi (macOS only):**

```bash
# Install CocoaPods
sudo gem install cocoapods

# Update CocoaPods repo
pod repo update

# Clean iOS build
cd ios
rm -rf Pods
rm Podfile.lock
pod install
cd ..

# Rebuild Flutter
flutter clean
flutter pub get
flutter run
```

---

### 6. ❌ Error: "Build Runner stuck atau code generation failed"

**Gejala:**
```
Watching library updates... (ready for 0 seconds)
```

**Solusi:**

```bash
# Stop process (Ctrl+C)

# Clean build
flutter clean
rm pubspec.lock

# Fresh install
flutter pub get

# Run build runner dengan verbose mode
flutter pub run build_runner build --verbose

# Atau gunakan delete-conflicting-outputs
flutter pub run build_runner build --delete-conflicting-outputs

# Jika tetap bermasalah, coba build runner langsung
flutter pub global activate build_runner
pub run build_runner build
```

---

### 7. ❌ Error: "Permission denied" pada Linux/macOS

**Gejala:**
```
Permission denied: ./gradlew
```

**Solusi:**

```bash
# Grant execute permission
chmod +x gradlew
chmod +x ios/Pods/Firebase/*/Frameworks/*.framework

# Atau untuk semua shell scripts:
find . -name "*.sh" -exec chmod +x {} \;

# Coba jalankan lagi
flutter run
```

---

### 8. ❌ Error: "Hive adapter not registered"

**Gejala:**
```
HiveError: Adapter not registered: 0
```

**Solusi:**

```dart
// Pastikan di main.dart, adapter sudah diregister
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Hive.initFlutter();
  
  // Register adapters SEBELUM membuka box
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(LogModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LogCategoryAdapter());
  }
  
  await Hive.openBox<LogModel>('offline_logs');
  
  runApp(const MyApp());
}
```

**Terminal command:**
```bash
# Rebuild code generation
flutter pub run build_runner build --delete-conflicting-outputs

# Clean dan rebuild app
flutter clean
flutter pub get
flutter run
```

---

### 9. ❌ Error: "Network/Connectivity issue"

**Gejala:**
```
SocketException: Failed to resolve 'api.example.com'
```

**Solusi:**

```dart
// Gunakan connectivity_plus untuk check internet
import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> hasInternet() async {
  final result = await Connectivity().checkConnectivity();
  return result != ConnectivityResult.none;
}

// Di app, check internet sebelum request:
if (await hasInternet()) {
  // Lakukan request
} else {
  // Gunakan data offline atau show snackbar
}
```

**Terminal command:**
```bash
# Check network
ping google.com

# Jika menggunakan proxy, set environment variable:
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080
```

---

### 10. ❌ Error: "Hot Reload tidak bekerja"

**Gejala:**
```
Hot reload failed, performing full restart...
```

**Solusi:**

```bash
# Hot reload tidak berfungsi jika ada perubahan:
# - Constructor
# - static fields
# - main.dart changes
# - Plugin changes

# Solusi: Gunakan Hot Restart (Tekan R)
# atau restart manual:
flutter run --no-fast-start

# Atau dengan fresh build:
flutter clean
flutter run -v
```

---

## 📚 Struktur Kode dan SRP Explanation

### Single Responsibility Principle (SRP) dalam Proyek

Setiap file dan class dalam proyek ini dirancang dengan satu tanggung jawab utama:

#### 1. **Models** (`lib/features/logbook/models/`)
- **Tanggung Jawab:** Mendefinisikan struktur data
- **File:** `log_model.dart`, `log_category.dart`
- **Prinsip:** Hanya berisi data structure, tidak ada business logic

#### 2. **Services** (`lib/services/`)
- **Tanggung Jawab:** Handle komunikasi dengan eksternal (DB, API)
- **File:** `storage_service.dart`, `connectivity_service.dart`
- **Prinsip:** Terpisah dari UI dan business logic

#### 3. **Views & Pages** (`lib/features/logbook/views/`)
- **Tanggung Jawab:** Menampilkan UI dan handle user interaction
- **File:** `*.dart` UI files
- **Prinsip:** Hanya mengurus presentation layer

#### 4. **Helpers** (`lib/helpers/`)
- **Tanggung Jawab:** Menyediakan utility functions
- **File:** Helper functions untuk formatting, validation, dll
- **Prinsip:** Reusable functions, tidak terikat ke satu domain

---

### Keuntungan Penerapan SRP dalam Proyek:

✅ **Testing Lebih Mudah** - Setiap layer dapat ditest terpisah  
✅ **Maintenance** - Perubahan di satu layer tidak mempengaruhi layer lain  
✅ **Reusability** - Services dapat digunakan di berbagai place  
✅ **Readability** - Developer baru lebih mudah memahami kode  
✅ **Scalability** - Mudah menambah fitur baru tanpa mengubah kode existing  

---

## 📞 Support dan Referensi

### Dokumentasi Resmi
- 🔗 [Flutter Official Docs](https://flutter.dev/docs)
- 🔗 [Dart Official Docs](https://dart.dev/guides)
- 🔗 [SOLID Principles](https://en.wikipedia.org/wiki/SOLID)
- 🔗 [Flutter Testing Guide](https://flutter.dev/docs/testing)

### Komunitas
- 💬 [Flutter Community](https://flutter.dev/community)
- 💬 [Stack Overflow - Flutter Tag](https://stackoverflow.com/questions/tagged/flutter)

### Tools Rekomendasi
- 📦 [Pub.dev](https://pub.dev) - Package registry untuk Dart/Flutter
- 🧪 [DevTools](https://flutter.dev/docs/development/tools/devtools) - Debugging dan profiling tool
- 🎨 [Material Design](https://material.io/design) - UI/UX guidelines

---

## 📝 Git Workflow (Opsional)

```bash
# Clone repo
git clone <URL_REPO>

# Create feature branch
git checkout -b feature/nama-fitur

# Commit changes
git add .
git commit -m "feat: deskripsi fitur"

# Push ke remote
git push origin feature/nama-fitur

# Create Pull Request
# (Lakukan di GitHub/GitLab/Bitbucket)
```

---

## ✅ Checklist Setup Selesai

Pastikan semua langkah berikut sudah selesai sebelum mulai development:

- [ ] Flutter SDK terinstall dan di PATH
- [ ] Android SDK / Xcode terinstall (sesuai platform)
- [ ] `flutter doctor` menunjukkan ✓
- [ ] Clone/download project
- [ ] `flutter pub get` selesai
- [ ] `flutter pub run build_runner build` selesai
- [ ] `.env` file sudah dikonfigurasi
- [ ] Devices sudah terdeteksi dengan `flutter devices`
- [ ] `flutter run` berhasil dan app berjalan
- [ ] Tests berjalan dengan `flutter test`

---

## 📄 Lisensi

Project ini dibuat untuk tujuan pendidikan. Silakan gunakan sebagai referensi pembelajaran.

---

**Happy Coding! 🚀**  
Jika ada pertanyaan atau error yang tidak tercakup di sini, silakan create issue atau hubungi tim development. 

**Penjelasan SRP:**
- Class `CounterController` **hanya** menangani:
  - Penyimpanan nilai counter
  - Operasi increment, decrement, reset
  - Pencatatan history
- **Tidak mengetahui** bagaimana data ditampilkan (UI)
- **Tidak bergantung** pada Flutter widgets
- Mudah diuji secara unit test tanpa UI

---

### 3. `counter_view.dart` - Presentation Layer

**Tanggung Jawab:** Menampilkan UI dan menangani interaksi pengguna.

**Penjelasan SRP:**
- Class `CounterView` **hanya** menangani:
  - Rendering tampilan (Scaffold, Text, Buttons)
  - Menangkap input pengguna
  - Memanggil controller untuk operasi bisnis
- **Tidak mengetahui** bagaimana perhitungan dilakukan
- **Tidak menyimpan** logic bisnis

---

## 📊 Diagram Pemisahan Tanggung Jawab

```
┌─────────────────────────────────────────────────────────┐
│                        main.dart                         │
│              (Konfigurasi & Entry Point)                 │
└─────────────────────────┬───────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────┐
│                    counter_view.dart                     │
│                    (Presentation Layer)                  │
│  - Menampilkan UI                                        │
│  - Menangani input user                                  │
│  - Memanggil controller                                  │
└─────────────────────────┬───────────────────────────────┘
                          │ uses
                          ▼
┌─────────────────────────────────────────────────────────┐
│                 counter_controller.dart                  │
│                   (Business Logic Layer)                 │
│  - Menyimpan state counter                               │
│  - Operasi: increment, decrement, reset                  │
│  - Mengelola history                                     │
└─────────────────────────────────────────────────────────┘
```

---

## ⚖️ Perbandingan: Dengan SRP vs Tanpa SRP

### ❌ Tanpa SRP (Anti-Pattern)

Ketika semua logic bisnis dan UI digabungkan dalam satu class:
- Sulit di-maintain karena satu perubahan bisa berdampak ke banyak bagian
- Sulit di-test karena UI dan logic tercampur
- Perubahan UI bisa mempengaruhi logic bisnis
- Kode tidak reusable

### ✅ Dengan SRP (Best Practice)

Ketika Controller dan View dipisahkan:
- Mudah di-maintain karena setiap class fokus pada satu tugas
- Controller bisa di-test tanpa perlu menjalankan UI
- Perubahan UI tidak mempengaruhi logic bisnis
- Controller bisa digunakan kembali di tempat lain

---

## 📝 Kesimpulan

Pada praktikum ini, prinsip **Single Responsibility Principle (SRP)** diterapkan dengan memisahkan aplikasi menjadi tiga komponen utama:

| File | Tanggung Jawab | Alasan Berubah |
|------|----------------|----------------|
| `main.dart` | Konfigurasi aplikasi | Perubahan tema/routing |
| `counter_controller.dart` | Logic bisnis counter | Perubahan cara perhitungan |
| `counter_view.dart` | Tampilan UI | Perubahan desain tampilan |

Dengan pemisahan ini, setiap komponen memiliki **satu alasan untuk berubah**, sehingga kode lebih **mudah dipelihara, diuji, dan dikembangkan**.

---
# B5_PCD_RapSign
