// login_view.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:logbook_app_001/features/auth/login_controller.dart';
// import 'package:logbook_app_001/features/logbook/counter_view.dart';
import 'package:logbook_app_001/features/home/home_page.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});
  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  // Inisialisasi Otak dan Controller Input
  final LoginController _controller = LoginController();
  bool _isPasswordVisible = false;
  String? _errorMessage;

  // Variabel untuk fitur lock setelah 3x gagal
  int _failedAttempts = 0;
  bool _isLocked = false;
  int _lockSeconds = 10;
  Timer? _lockTimer;

  // Method untuk memulai timer lock
  void _startLockTimer() {
    _lockSeconds = 10;
    _isLocked = true;

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_lockSeconds > 0) {
          _lockSeconds--;
        } else {
          // Waktu habis, unlock tombol
          _isLocked = false;
          _failedAttempts = 0;
          _errorMessage = null;
          timer.cancel();
        }
      });
    });
  }

  void _handleLogin() {
    // Cek apakah tombol sedang dikunci
    if (_isLocked) return;

    final username = _controller.usernameController.text.trim();
    final password = _controller.passwordController.text.trim();

    // Validasi input kosong
    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = 'Username dan password harus diisi';
      });
      return;
    }

    // Proses login
    final userData = _controller.login(username, password);
    if (userData != null) {
      // Login berhasil - reset counter
      setState(() {
        _errorMessage = null;
        _failedAttempts = 0;
      });

      // Pindah ke HomePage dengan data user lengkap
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomePage(
            username: username,
            teamId: userData['teamId'] as String? ?? '1',
            role: userData['role'] as String? ?? 'Anggota',
          ),
        ),
        (route) => false,
      );
    } else {
      // Login gagal - tambah counter
      setState(() {
        _failedAttempts++;

        if (_failedAttempts >= 3) {
          // Lock tombol selama 10 detik
          _errorMessage =
              'Terlalu banyak percobaan! Coba lagi dalam $_lockSeconds detik';
          _startLockTimer();
        } else {
          _errorMessage = 'Username atau password salah ($_failedAttempts/3)';
        }
      });
    }
  }

  @override
  void dispose() {
    _lockTimer?.cancel(); // Cancel timer saat dispose
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo atau Icon
                const Icon(
                  Icons.account_circle,
                  size: 100,
                  color: Color(0xFF8A6F4D),
                ),
                const SizedBox(height: 20),

                // Judul
                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF3D3D3D),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 8),

                // Subtitle
                const Text(
                  'Masuk ke akun Anda',
                  style: TextStyle(fontSize: 16, color: Color(0xFF8B7D6B)),
                ),
                const SizedBox(height: 40),

                // Username Field
                TextField(
                  controller: _controller.usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Field
                TextField(
                  controller: _controller.passwordController,
                  obscureText: !_isPasswordVisible,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Error Message
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _isLocked
                          ? const Color(0xFFF5E6D3)
                          : const Color(0xFFF5E0DC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _isLocked
                            ? const Color(0xFFC2A35C)
                            : const Color(0xFF9E5A5A),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isLocked ? Icons.lock_clock : Icons.error_outline,
                          color: _isLocked
                              ? const Color(0xFFC2A35C)
                              : const Color(0xFF9E5A5A),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _isLocked
                                ? 'Terlalu banyak percobaan! Coba lagi dalam $_lockSeconds detik'
                                : _errorMessage!,
                            style: TextStyle(
                              color: _isLocked
                                  ? const Color(0xFF8A6F4D)
                                  : const Color(0xFF9E5A5A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // Tombol Login
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLocked ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLocked
                          ? const Color(0xFF8B7D6B)
                          : const Color(0xFF8A6F4D),
                      foregroundColor: const Color(0xFFF3EBDD),
                      elevation: 2,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      _isLocked ? 'Tunggu $_lockSeconds detik' : 'Login',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Daftar akun yang tersedia (untuk testing)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EBDD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF8B7D6B).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Akun tersedia (untuk testing):',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF8A6F4D),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• admin : admin123',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• user1 : password1',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• user2 : password2',
                        style: TextStyle(fontSize: 12),
                      ),
                      const Text(
                        '• aruman : aruman123',
                        style: TextStyle(fontSize: 12),
                      ),
                    const Text(
                        '• reviewer1 : reviewer123',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
