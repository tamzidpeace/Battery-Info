import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> main() async {
  // needed if you intend to initialize in the `main` function
  WidgetsFlutterBinding.ensureInitialized();

  const MacOSInitializationSettings initializationSettingsMacOS = MacOSInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    macOS: initializationSettingsMacOS,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings, onSelectNotification: (String? payload) async {
    if (payload != null) {
      debugPrint('notification payload: $payload');
    }

    debugPrint('flutterLocalNotificationsPlugin.initialize: here');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Battery Info',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Home'),
    );
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Battery _battery = Battery();
  int batterLevel = 0;

  BatteryState? _batteryState;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  @override
  void initState() {
    super.initState();
    // notification related
    _requestPermissions();

    /// batter related
    _battery.batteryState.then(_updateBatteryState);
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen(_updateBatteryState);

    //runs the function every 60 seconds
    Timer.periodic(const Duration(seconds: 60), (Timer t) {
      _battery.batteryLevel.then((int level) {
        setState(() {
          batterLevel = level;
        });
        if (kDebugMode) {
          print(batterLevel.toDouble());
        }
        if (level >= 80) {
          _showNotificationWithNoTitle(level: level);
        }
      });
    });
  }

  void _requestPermissions() {
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _updateBatteryState(BatteryState state) {
    if (_batteryState == state) return;
    setState(() {
      _batteryState = state;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // remove debug banner

      appBar: AppBar(
        title: const Text('Battery Info'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Batter Level: $batterLevel'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final batteryLevel = await _battery.batteryLevel;
                // ignore: unawaited_futures
                showDialog<void>(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: Text('Battery: $batteryLevel%'),
                    actions: <Widget>[
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text('OK'),
                      )
                    ],
                  ),
                );
              },
              child: const Text('Get battery level'),
            ),
            ElevatedButton(onPressed: () => _showNotificationWithNoTitle(level: 10), child: Text('data'))
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
    if (_batteryStateSubscription != null) {
      _batteryStateSubscription!.cancel();
    }
  }

  Future<void> _showNotificationWithNoTitle({required int level}) async {
    await flutterLocalNotificationsPlugin.cancel(0);

    MacOSNotificationDetails macosPlatformChannelSpecifics = MacOSNotificationDetails(
      subtitle: 'Current Battery Level: $level%',
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(macOS: macosPlatformChannelSpecifics);

    var message = 'Battery Level: $level%';

    if (level >= 99) {
      message = 'Battery Level: $level% - Please unplug the charger';

      flutterLocalNotificationsPlugin.show(
        0,
        'Warning',
        message,
        platformChannelSpecifics,
      );
    } else if (level <= 30) {
      message = 'Battery Level: $level% - Please plug the charger';

      flutterLocalNotificationsPlugin.show(
        0,
        'Warning',
        message,
        platformChannelSpecifics,
      );
    }
  }
}
