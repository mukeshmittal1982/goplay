import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tennis App Hello World',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String _message = 'Press the button to fetch message';
  List<dynamic> _roles = [];

  // Replace with your local IP or ngrok URL for mobile testing
  // For Android Emulator, use 10.0.2.2
  // For iOS Simulator/Web, use localhost
  final String _baseUrl = 'https://mae-interregnal-carmen.ngrok-free.dev';

  Future<void> _fetchHello() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/hello'));
      if (response.statusCode == 200) {
        setState(() {
          _message = json.decode(response.body)['message'];
        });
      } else {
        setState(() {
          _message = 'Error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Failed to connect to backend: $e';
      });
    }
  }

  Future<void> _fetchRoles() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/db-test'));
      if (response.statusCode == 200) {
        setState(() {
          _roles = json.decode(response.body)['roles'];
        });
      }
    } catch (e) {
      print('Failed to fetch roles: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tennis App Tech Stack Test'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Backend Response:'),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _message,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _fetchHello();
                _fetchRoles();
              },
              child: const Text('Fetch from Backend'),
            ),
            const SizedBox(height: 40),
            if (_roles.isNotEmpty) ...[
              const Text('Roles from Database:'),
              ..._roles.map((role) => Text(role['name'])),
            ]
          ],
        ),
      ),
    );
  }
}
