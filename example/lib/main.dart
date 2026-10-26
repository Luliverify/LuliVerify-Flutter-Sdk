import 'package:flutter/material.dart';
import 'package:luliverify_flutter/luliverify_flutter.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});
  @override
  Widget build(BuildContext context) {
    final config = LuliVerifyConfig(
      apiBaseUrl: Uri.parse('https://api.example.com'),
    );
    return MaterialApp(
      title: 'LuliVerify',
      home: Scaffold(
        appBar: AppBar(title: const Text('LuliVerify')),
        body: Center(child: Text(config.presentation.name)),
      ),
    );
  }
}
