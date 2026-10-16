import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
  static const String _email = 'adminiot@example.com';
  static const String _password = 'passwordrahasia123';
  static const int _maxHistoryPoints = 12;

  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool? _isConnected;
  String _errorMessage = '';

  double? _suhu;
  double? _kelembapan;
  int? _ledStatus;

  final List<double> _temperatureHistory = <double>[];
  final List<double> _humidityHistory = <double>[];

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref('esiot-db');
  StreamSubscription<DatabaseEvent>? _connectionSubscription;
  StreamSubscription<DatabaseEvent>? _sensorSubscription;
  StreamSubscription<DatabaseEvent>? _ledSubscription;

  @override
  void initState() {
    super.initState();
    _listenForConnection();
    _authenticateUser();
  }

  void _listenForConnection() {
    _connectionSubscription = FirebaseDatabase.instance
        .ref('.info/connected')
        .onValue
        .listen(
          (event) {
            if (!mounted) return;
            setState(() {
              _isConnected = event.snapshot.value == true;
            });
          },
          onError: (Object error) {
            debugPrint('Firebase connection listener failed: $error');
            if (!mounted) return;
            setState(() {
              _isConnected = false;
            });
          },
        );
  }

  Future<void> _authenticateUser() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email,
        password: _password,
      );

      if (!mounted) return;

      setState(() {
        _isAuthenticated = true;
        _isLoading = false;
      });

      _setupDatabaseListeners();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = error.message ?? 'Terjadi kesalahan autentikasi';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Gagal melakukan autentikasi: $error';
      });
    }
  }

  void _setupDatabaseListeners() {
    _sensorSubscription = _dbRef.child('sensor').onValue.listen((event) {
      final temperatureValue = event.snapshot.child('suhu').value;
      final humidityValue = event.snapshot.child('kelembapan').value;
      final temperature = temperatureValue is num
          ? temperatureValue.toDouble()
          : _suhu;
      final humidity = humidityValue is num
          ? humidityValue.toDouble()
          : _kelembapan;

      if (temperature == null || humidity == null) return;
      if (!mounted) return;
      setState(() {
        _suhu = temperature;
        _kelembapan = humidity;
        _temperatureHistory.add(temperature);
        _humidityHistory.add(humidity);
        if (_temperatureHistory.length > _maxHistoryPoints) {
          _temperatureHistory.removeAt(0);
          _humidityHistory.removeAt(0);
        }
      });
    });

    _ledSubscription = _dbRef.child('kontrol/led').onValue.listen((event) {
      final value = event.snapshot.value;
      if (value == null) return;

      if (!mounted) return;
      setState(() {
        _ledStatus = (value as num).toInt();
      });
    });
  }

  @override
  void dispose() {
    unawaited(_connectionSubscription?.cancel());
    unawaited(_sensorSubscription?.cancel());
    unawaited(_ledSubscription?.cancel());
    super.dispose();
  }

  Future<void> _toggleLed() async {
    if (_ledStatus == null) {
      return;
    }

    final newStatus = _ledStatus == 1 ? 0 : 1;

    try {
      await _dbRef.child('kontrol/led').set(newStatus);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal mengubah LED: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF172B4D),
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.sensors_rounded,
                color: Color(0xFF1976D2),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Monitoring IoT',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Pantau kondisi perangkat',
                    style: TextStyle(fontSize: 11, color: Color(0xFF718096)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _buildConnectionIndicator()),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Color(0xFFE8EDF3)),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildConnectionIndicator() {
    final connected = _isConnected == true;
    final label = _isConnected == null
        ? 'Memeriksa'
        : connected
        ? 'Terhubung'
        : 'Terputus';
    final color = connected ? const Color(0xFF218838) : const Color(0xFFB54708);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFE8F5E9) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isConnected == null)
            const SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5),
            )
          else
            Icon(
              connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              size: 14,
              color: color,
            ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Gagal Login:\n$_errorMessage',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDataCard(
                title: 'Suhu',
                value: _suhu != null
                    ? '${_suhu!.toStringAsFixed(1)} °C'
                    : '-- °C',
                icon: Icons.thermostat,
                color: Colors.orange,
                accent: const Color(0xFFFFF3E0),
              ),
              const SizedBox(height: 8),
              _buildDataCard(
                title: 'Kelembapan',
                value: _kelembapan != null
                    ? '${_kelembapan!.toStringAsFixed(1)} %'
                    : '-- %',
                icon: Icons.water_drop,
                color: Colors.blue,
                accent: const Color(0xFFE3F2FD),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildHistoryChart()),
              const SizedBox(height: 8),
              _buildLedButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDataCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: accent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLedButton() {
    final isOn = _ledStatus == 1;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _toggleLed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: isOn
                  ? [const Color(0xFF2ECC71), const Color(0xFF27AE60)]
                  : [const Color(0xFFE9EEF5), const Color(0xFFCFD8E3)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (isOn ? Colors.green : Colors.grey).withValues(
                  alpha: 0.25,
                ),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: isOn ? 0.18 : 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOn ? Icons.lightbulb : Icons.lightbulb_outline,
                      color: isOn ? Colors.white : Colors.black87,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kontrol Lampu',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOn
                              ? Colors.white
                              : Colors.black87.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        isOn ? 'Lampu Nyala' : 'Lampu Mati',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isOn ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: isOn ? Colors.white : Colors.grey.shade600,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryChart() {
    const temperatureColor = Colors.orange;
    const humidityColor = Colors.blue;
    final temperatureSpots = [
      for (var i = 0; i < _temperatureHistory.length; i++)
        FlSpot(i.toDouble(), _temperatureHistory[i]),
    ];
    final humiditySpots = [
      for (var i = 0; i < _humidityHistory.length; i++)
        FlSpot(i.toDouble(), _humidityHistory[i]),
    ];
    final lastIndex = _temperatureHistory.length - 1;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172B4D).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FA),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: Color(0xFF52657A),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Riwayat Data',
                      style: TextStyle(
                        color: Color(0xFF172B4D),
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Perubahan pembacaan sensor',
                      style: TextStyle(color: Color(0xFF718096), fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_temperatureHistory.length}/$_maxHistoryPoints data',
                  style: const TextStyle(
                    color: Color(0xFF718096),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.fromLTRB(4, 8, 10, 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: 100,
                      minX: 0,
                      maxX: lastIndex < 1 ? 1 : lastIndex.toDouble(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 25,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: const Color(0xFFE4EAF1),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: const Border(
                          left: BorderSide(color: Color(0xFF9AA8B8)),
                          bottom: BorderSide(color: Color(0xFF9AA8B8)),
                        ),
                      ),
                      lineTouchData: LineTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 50,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) => Text(
                              value.toInt().toString(),
                              style: const TextStyle(
                                color: Color(0xFF718096),
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      lineBarsData: [
                        _buildChartLine(
                          spots: temperatureSpots,
                          color: temperatureColor,
                        ),
                        _buildChartLine(
                          spots: humiditySpots,
                          color: humidityColor,
                        ),
                      ],
                    ),
                  ),
                  if (temperatureSpots.isEmpty)
                    Center(
                      child: Text(
                        'Menunggu data sensor...',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Suhu', temperatureColor),
              const SizedBox(width: 20),
              _buildLegendItem('Kelembapan', humidityColor),
            ],
          ),
        ],
      ),
    );
  }

  LineChartBarData _buildChartLine({
    required List<FlSpot> spots,
    required Color color,
  }) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 2.5,
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
      spots: spots,
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 16, height: 3, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF52657A),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
