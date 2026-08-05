// Deferred import loader for KalenderScreen to improve app start time
import 'package:flutter/material.dart';
import 'package:wachbuch_mobile/api/client.dart';
import 'package:wachbuch_mobile/screens/kalender_screen.dart' as kalender;

class KalenderScreenDeferred extends StatelessWidget {
  const KalenderScreenDeferred({super.key, required this.api});

  final WachbuchApi api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: kalender.loadLibrary(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Failed to load calendar module: ${snapshot.error}'),
            );
          }
          return kalender.KalenderScreen(api: api);
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}
