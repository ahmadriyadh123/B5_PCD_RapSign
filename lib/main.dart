import 'package:flutter/material.dart';
import 'features/signature/models/verification_log_model.dart';
// import 'package:logbook_app_001/features/logbook/log_view.dart';
import 'package:camera/camera.dart';
import 'features/onboarding/onboarding_view.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'features/logbook/models/log_model.dart';

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  // Initialize HistoryService (SharedPreferences)
  // await HistoryService().init();
  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(LogModelAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(LogCategoryAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
  Hive.registerAdapter(VerificationLogModelAdapter());
  }
  await Hive.openBox<VerificationLogModel>('verification_logs');

  await Hive.openBox<LogModel>('offline_logs');
  try {
    // Ambil daftar kamera yang tersedia di perangkat
    cameras = await availableCameras();
  } on CameraException catch (e) {
    print('Error: ${e.code}\nError Message: ${e.description}');
  }
  

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // Vintage Color Palette
  static const Color warmBrown = Color(0xFF8A6F4D); // Primary
  static const Color mutedGold = Color(0xFFC2A35C); // Accent
  static const Color warmBeige = Color(0xFFE6D8C3); // Background
  static const Color softCream = Color(0xFFF3EBDD); // Surface/Card
  static const Color charcoalGray = Color(0xFF3D3D3D); // Text
  static const Color taupe = Color(0xFF8B7D6B); // Secondary text

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Logbook',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: warmBeige,
        colorScheme: ColorScheme(
          brightness: Brightness.light,
          primary: warmBrown,
          onPrimary: softCream,
          secondary: mutedGold,
          onSecondary: charcoalGray,
          surface: softCream,
          onSurface: charcoalGray,
          error: const Color(0xFF9E5A5A),
          onError: softCream,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: warmBrown,
          foregroundColor: softCream,
          elevation: 2,
          shadowColor: Color(0x40000000),
        ),
        cardTheme: CardThemeData(
          color: softCream,
          elevation: 2,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: warmBrown,
            foregroundColor: softCream,
            elevation: 2,
            shadowColor: Colors.black26,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: warmBrown),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: mutedGold,
          foregroundColor: charcoalGray,
          elevation: 3,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: softCream,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: taupe),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: taupe),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: warmBrown, width: 2),
          ),
          labelStyle: const TextStyle(color: taupe),
          hintStyle: const TextStyle(color: taupe),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: softCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        dividerTheme: const DividerThemeData(color: taupe, thickness: 0.5),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            color: charcoalGray,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            color: charcoalGray,
            fontWeight: FontWeight.bold,
          ),
          displaySmall: TextStyle(
            color: charcoalGray,
            fontWeight: FontWeight.bold,
          ),
          headlineLarge: TextStyle(
            color: charcoalGray,
            fontWeight: FontWeight.w600,
          ),
          headlineMedium: TextStyle(
            color: charcoalGray,
            fontWeight: FontWeight.w600,
          ),
          headlineSmall: TextStyle(
            color: charcoalGray,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            color: charcoalGray,
            fontWeight: FontWeight.w500,
          ),
          titleMedium: TextStyle(color: charcoalGray),
          titleSmall: TextStyle(color: charcoalGray),
          bodyLarge: TextStyle(color: charcoalGray),
          bodyMedium: TextStyle(color: charcoalGray),
          bodySmall: TextStyle(color: taupe),
          labelLarge: TextStyle(
            color: charcoalGray,
            fontWeight: FontWeight.w500,
          ),
          labelMedium: TextStyle(color: charcoalGray),
          labelSmall: TextStyle(color: taupe),
        ),
        iconTheme: const IconThemeData(color: charcoalGray),
        listTileTheme: const ListTileThemeData(
          iconColor: warmBrown,
          textColor: charcoalGray,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: warmBrown,
          contentTextStyle: const TextStyle(color: softCream),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      home: const OnboardingView(),
    );
  }
}

// // class MyHomePage extends StatefulWidget {
// //   const MyHomePage({super.key, required this.title});

// //   // This widget is the home page of your application. It is stateful, meaning
// //   // that it has a State object (defined below) that contains fields that affect
// //   // how it looks.

// //   // This class is the configuration for the state. It holds the values (in this
// //   // case the title) provided by the parent (in this case the App widget) and
// //   // used by the build method of the State. Fields in a Widget subclass are
// //   // always marked "final".

// //   final String title;

// //   @override
// //   State<MyHomePage> createState() => _MyHomePageState();
// // }

// // class _MyHomePageState extends State<MyHomePage> {
// //   int _counter = 0;
// //   int _step = 5;
// //   void _incrementCounter() {
// //     setState(() {
// //       // This call to setState tells the Flutter framework that something has
// //       // changed in this State, which causes it to rerun the build method below
// //       // so that the display can reflect the updated values. If we changed
// //       // _counter without calling setState(), then the build method would not be
// //       // called again, and so nothing would appear to happen.
// //       _counter = _counter + _step;
// //     });
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     // This method is rerun every time setState is called, for instance as done
// //     // by the _incrementCounter method above.
// //     //
// //     // The Flutter framework has been optimized to make rerunning build methods
// //     // fast, so that you can just rebuild anything that needs updating rather
// //     // than having to individually change instances of widgets.
// //     return Scaffold(
// //       appBar: AppBar(
// //         // TRY THIS: Try changing the color here to a specific color (to
// //         // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
// //         // change color while the other colors stay the same.
// //         backgroundColor: Theme.of(context).colorScheme.inversePrimary,
// //         // Here we take the value from the MyHomePage object that was created by
// //         // the App.build method, and use it to set our appbar title.
// //         title: Text(widget.title),
// //       ),
// //       body: Center(
// //         // Center is a layout widget. It takes a single child and positions it
// //         // in the middle of the parent.
// //         child: Column(
// //           // Column is also a layout widget. It takes a list of children and
// //           // arranges them vertically. By default, it sizes itself to fit its
// //           // children horizontally, and tries to be as tall as its parent.
// //           //
// //           // Column has various properties to control how it sizes itself and
// //           // how it positions its children. Here we use mainAxisAlignment to
// //           // center the children vertically; the main axis here is the vertical
// //           // axis because Columns are vertical (the cross axis would be
// //           // horizontal).
// //           //
// //           // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
// //           // action in the IDE, or press "p" in the console), to see the
// //           // wireframe for each widget.
// //           mainAxisAlignment: .center,
// //           children: [
// //             const Text('You have pushed the button this many times:'),
// //             Text(
// //               '$_counter',
// //               style: Theme.of(context).textTheme.headlineMedium,
// //             ),
// //           ],
// //         ),
// //       ),
// //       floatingActionButton: FloatingActionButton(
// //         onPressed: _incrementCounter,
// //         tooltip: 'Increment',
// //         child: const Icon(Icons.add),
// //       ),
// //     );
// //   }
// }
