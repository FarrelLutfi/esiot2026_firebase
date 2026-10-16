Dokumen Spesifikasi Teknis: Aplikasi Monitoring & Kontrol IoT
1. Deskripsi Umum
Aplikasi mobile berbasis Android (dibangun menggunakan framework Flutter) yang berfungsi untuk melakukan monitoring data sensor (suhu dan kelembapan) secara real-time serta mengendalikan aktuator (LED). Aplikasi ini terintegrasi dengan Firebase Realtime Database dan menggunakan Firebase Authentication untuk mengamankan akses baca/tulis data.

2. Fitur Inti
Autentikasi Latar Belakang (Background Authentication): Proses login menggunakan Email/Password berjalan otomatis di latar belakang tanpa antarmuka form login, menggunakan kredensial yang telah diatur (hardcoded) dalam skrip.

Monitoring Real-Time: Menampilkan nilai Suhu (Float) dan Kelembapan (Float) yang akan diperbarui secara otomatis setiap kali ada perubahan data pada server Firebase.

Kontrol Aktuator (Toggle LED): Tombol interaktif untuk mengubah status LED secara bergantian antara 0 (Mati) dan 1 (Hidup).

3. Alur Pengguna (User Flow)
Inisialisasi: Pengguna membuka aplikasi. Layar menampilkan indikator pemuatan (loading spinner).

Proses Autentikasi: Aplikasi mencoba masuk (sign-in) ke Firebase secara otomatis menggunakan variabel email dan password yang tersemat di sistem.

Sinkronisasi Data: Setelah autentikasi berhasil, aplikasi mendaftarkan listener ke node database /esiot-db/sensor dan /esiot-db/kontrol.

Tampilan Utama (Dashboard): Layar menampilkan data Suhu dan Kelembapan terkini, serta tombol kontrol LED.

Aksi Pengguna:

Jika pengguna menekan tombol "Toggle LED", aplikasi membaca state LED saat ini.

Jika state saat ini 0, sistem akan mengirimkan nilai 1 ke database, dan sebaliknya.

UI tombol (warna/teks) akan beradaptasi sesuai dengan status LED yang berhasil diperbarui di database.

4. Skema Database (Firebase Realtime Database)
Struktur JSON yang digunakan dalam sistem IoT:

JSON
{
  "esiot-db": {
    "kontrol": {
      "led": 0
    },
    "sensor": {
      "kelembapan": 65.5,
      "suhu": 28.4
    }
  }
}
Aturan Keamanan (Security Rules): Hak akses .read dan .write dibatasi hanya untuk sesi pengguna yang memiliki token autentikasi valid (auth != null) pada node esiot-db.

5. Prasyarat & Kebutuhan Dependensi
Agar kode dapat berjalan, wajib menambahkan pustaka berikut pada file pubspec.yaml:

YAML
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^latest_version
  firebase_auth: ^latest_version
  firebase_database: ^latest_version
Implementasi Kode Flutter
Berikut adalah implementasi lengkap pada file main.dart. Pastikan Anda telah mengonfigurasi firebase_options.dart menggunakan FlutterFire CLI sebelumnya.

Dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'firebase_options.dart'; // File hasil generate FlutterFire

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'IoT Monitoring App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // === VARIABEL KREDENSIAL AUTHENTICATION ===
  // Sesuaikan email dan password ini dengan akun yang terdaftar di Firebase Auth
  final String _email = 'adminiot@example.com';
  final String _password = 'passwordrahasia123';

  // State Variables
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _errorMessage = '';

  // Data Variables
  double? _suhu;
  double? _kelembapan;
  int? _ledStatus; // 0 = Mati, 1 = Hidup

  // Database Reference
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('esiot-db');

  @override
  void initState() {
    super.initState();
    _authenticateUser();
  }

  // Fungsi untuk login otomatis di background
  Future<void> _authenticateUser() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );
      
      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });

      _setupDatabaseListeners();
      
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'Terjadi kesalahan autentikasi';
      });
    }
  }

  // Fungsi untuk mendengarkan perubahan data secara real-time
  void _setupDatabaseListeners() {
    // Listener Suhu
    _dbRef.child('sensor/suhu').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _suhu = (event.snapshot.value as num).toDouble();
        });
      }
    });

    // Listener Kelembapan
    _dbRef.child('sensor/kelembapan').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _kelembapan = (event.snapshot.value as num).toDouble();
        });
      }
    });

    // Listener Status LED
    _dbRef.child('kontrol/led').onValue.listen((event) {
      if (event.snapshot.value != null) {
        setState(() {
          _ledStatus = (event.snapshot.value as int);
        });
      }
    });
  }

  // Fungsi untuk mengubah status LED (Toggle)
  Future<void> _toggleLed() async {
    if (_ledStatus == null) return; // Mencegah klik jika data belum dimuat
    
    // Tentukan status baru (jika 1 jadi 0, jika 0 jadi 1)
    int newStatus = _ledStatus == 1 ? 0 : 1;
    
    try {
      await _dbRef.child('kontrol/led').set(newStatus);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengubah LED: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Melakukan Autentikasi...'),
          ],
        ),
      );
    }

    if (!_isAuthenticated) {
      return Center(
        child: Text(
          'Gagal Login:\n$_errorMessage',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red, fontSize: 16),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Kartu Informasi Suhu & Kelembapan
          Row(
            children: [
              Expanded(
                child: _buildDataCard(
                  title: 'Suhu',
                  value: _suhu != null ? '${_suhu!.toStringAsFixed(1)} °C' : '-- °C',
                  icon: Icons.thermostat,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildDataCard(
                  title: 'Kelembapan',
                  value: _kelembapan != null ? '${_kelembapan!.toStringAsFixed(1)} %' : '-- %',
                  icon: Icons.water_drop,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Bagian Kontrol LED
          const Text(
            'Kontrol Aktuator',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          ElevatedButton(
            onPressed: _toggleLed,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 24),
              backgroundColor: _ledStatus == 1 ? Colors.green : Colors.grey.shade300,
              foregroundColor: _ledStatus == 1 ? Colors.white : Colors.black87,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _ledStatus == 1 ? Icons.lightbulb : Icons.lightbulb_outline,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  _ledStatus == 1 ? 'LED MENYALA (1)' : 'LED MATI (0)',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget Helper untuk Kartu Data
  Widget _buildDataCard({required String title, required String value, required IconData icon, required Color color}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}