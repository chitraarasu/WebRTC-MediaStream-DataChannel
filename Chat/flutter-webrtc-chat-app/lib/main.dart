import 'dart:math';

import 'package:flutter/material.dart';
import 'screens/join_screen.dart';
import 'services/signalling.service.dart';

void main() {
  // start videoCall app
  runApp(ChatApp());
}

class ChatApp extends StatelessWidget {
  ChatApp({super.key});

  // signalling server url
  final String websocketUrl = "https://8feb-2405-201-e029-d172-5da-c4d7-b037-aae5.ngrok-free.app";

  // generate callerID of local user
  final String selfCallerID =
      Random().nextInt(999999).toString().padLeft(6, '0');

  @override
  Widget build(BuildContext context) {
    // init signalling service
    SignallingService.instance.init(
      websocketUrl: websocketUrl,
      selfCallerID: selfCallerID,
    );

    // return material app
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      darkTheme: ThemeData.dark().copyWith(
        useMaterial3: true,
        colorScheme: const ColorScheme.dark(),
      ),
      themeMode: ThemeMode.dark,
      home: JoinScreen(selfCallerId: selfCallerID),
    );
  }
}
