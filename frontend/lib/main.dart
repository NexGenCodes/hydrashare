import 'package:flutter/material.dart';
import 'services/daemon_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HydraShare',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'HydraShare - Daemon Connection'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final DaemonService _daemonService = DaemonService();
  final List<String> _logs = [];
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToDaemon();
  }

  Future<void> _connectToDaemon() async {
    try {
      _addLog('🔌 Attempting to connect to Go daemon...');

      await _daemonService.connect();

      setState(() {
        _isConnected = true;
      });

      _addLog('✅ Successfully connected to daemon');

      // Listen for responses
      _daemonService.responses.listen((response) {
        _addLog('📥 Response: ${response.toString()}');

        if (response['type'] == 'pong') {
          _addLog('🎉 HANDSHAKE SUCCESSFUL! Status: ${response['status']}');
        } else if (response['type'] == 'TRANSFER_STARTED') {
          _addLog('🚀 Transfer started: ${response['transfer_id']}');
        } else if (response['type'] == 'TRANSFER_PROGRESS') {
          final percentage = (response['percentage'] as num).toStringAsFixed(1);
          final speedMbps = (response['speed_mbps'] as num).toStringAsFixed(2);
          _addLog('📊 Progress: $percentage% @ $speedMbps MB/s');
        } else if (response['type'] == 'TRANSFER_COMPLETE') {
          _addLog('✅ Transfer completed successfully!');
        } else if (response['type'] == 'TRANSFER_ERROR') {
          _addLog('❌ Transfer error: ${response['error']}');
        }
      });

      // Send ping to verify connection
      _addLog('📤 Sending ping command...');
      await _daemonService.ping();
    } catch (e) {
      _addLog('❌ Connection failed: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)} - $message');
    });
    debugPrint(message);
  }

  Future<void> _sendPing() async {
    try {
      _addLog('📤 Sending ping...');
      await _daemonService.ping();
    } catch (e) {
      _addLog('❌ Failed to send ping: $e');
    }
  }

  Future<void> _startTransfer() async {
    try {
      // Demo: Send a transfer command
      // In production, you'd use a file picker dialog
      _addLog('📤 Sending START_TRANSFER command...');

      await _daemonService.sendCommand({
        'type': 'START_TRANSFER',
        'file_path': 'C:\\\\path\\\\to\\\\your\\\\file.txt', // Change this!
        'dest_ip': '192.168.1.100', // Change this!
      });
    } catch (e) {
      _addLog('❌ Failed to start transfer: $e');
    }
  }

  @override
  void dispose() {
    _daemonService.disconnect();
    _daemonService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: _isConnected ? Colors.green[100] : Colors.red[100],
            child: Row(
              children: [
                Icon(
                  _isConnected ? Icons.check_circle : Icons.error,
                  color: _isConnected ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  _isConnected ? '✅ Connected to daemon' : '❌ Not connected',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      _logs[index],
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Colors.greenAccent,
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isConnected ? _sendPing : null,
                  icon: const Icon(Icons.send),
                  label: const Text('Send Ping'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isConnected ? _startTransfer : null,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Start Transfer'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
