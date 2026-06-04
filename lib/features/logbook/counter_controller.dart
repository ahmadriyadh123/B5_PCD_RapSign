import 'package:shared_preferences/shared_preferences.dart';

class CounterController {
  int _counter = 0; // Variabel private (Enkapsulasi)
  int _step = 1; // default step = 1

  final List<String> _history = []; // variable riwayat penambahan step

  int get value => _counter; // Getter untuk akses data
  int get step => _step; // Getter untuk akses nilai step
  List<String> get history => _history; // Getter akses data riwayat

  // load data dari counter
  Future<void> loadCounter(String username) async {
    final prefs = await SharedPreferences.getInstance();
    _counter = prefs.getInt("counter_$username") ?? 0;
  }

  // simpan ke storage
  Future<void> saveCounter(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("counter_$username", _counter);
  }

  // Atur nilai step
  void setStep(int value) {
    if (value > 0) {
      _step = value;
    }
  }

  // add history counter
  void _addHistory(String username, String message) {
    DateTime now = DateTime.now();
    String time =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    _history.insert(0, "User $username $message pada jam $time");

    if (_history.length > 5) {
      _history.removeLast();
    }
  }

  //void increment() => _counter++;
  // Increment menggunakan step
  Future<void> increment(String username) async {
    _counter += _step;
    _addHistory(username, "menambah nilai sebesar $_step");

    await saveCounter(username); // simpan counter ke data lokal
  }

  // Decrement menggunakan step
  Future<void> decrement(String username) async {
    // subtract step but don't go below zero
    _counter = _counter - _step;
    if (_counter < 0) _counter = 0;
    _addHistory(username, "mengurangi nilai sebesar $_step");

    await saveCounter(username); // simpan counter ke data lokal
  }

  Future<void> reset(String username) async {
    _counter = 0;
    _addHistory(username, "mereset counter");

    await saveCounter(username); // simpan counter ke data lokal
  }
}
