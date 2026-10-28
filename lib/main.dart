import 'package:flutter/material.dart';
import 'compressor.dart';

void main() {
  runApp(const MudcApp());
}

class MudcApp extends StatelessWidget {
  const MudcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MUDC Utility',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple, brightness: Brightness.dark),
        useMaterial3: true,
      ),
      home: const MudcDashboard(),
    );
  }
}

class MudcDashboard extends StatefulWidget {
  const MudcDashboard({super.key});

  @override
  State<MudcDashboard> createState() => _MudcDashboardState();
}

class _MudcDashboardState extends State<MudcDashboard> {
  final MudcCompressor _compressor = MudcCompressor();
  String _status = "Ready to compress";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MUDC Compressor')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_zip_outlined, size: 72, color: Colors.deepPurpleAccent),
            const SizedBox(height: 16),
            Text(_status, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
