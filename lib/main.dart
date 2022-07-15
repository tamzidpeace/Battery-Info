import 'dart:async';
import 'package:flutter/material.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:hive/hive.dart';

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

  Hive.init('./hive');

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
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Battery _battery = Battery();
  int _batterLevel = 0;
  final TextEditingController _maxLevelController = TextEditingController(text: '99');
  final TextEditingController _minLevelController = TextEditingController(text: '30');

  BatteryState? _batteryState;
  StreamSubscription<BatteryState>? _batteryStateSubscription;

  // store data

  @override
  void initState() {
    super.initState();
    // notification related
    _requestPermissions();

    // batter related
    _battery.batteryState.then(_updateBatteryState);
    _batteryStateSubscription = _battery.onBatteryStateChanged.listen(_updateBatteryState);

    _storeBatteryPercentage();
  }

  void _requestPermissions() {
    flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  void _updateBatteryState(BatteryState state) async {
    debugPrint(state.toString());

    int level = await _battery.batteryLevel;
    debugPrint('_updateBatteryState: $level');

    if (level == _batterLevel) return;

    setState(() {
      _batterLevel = level;
    });

    _showNotificationWithNoTitle(
      level: level,
      max: int.parse(_maxLevelController.text),
      min: int.parse(_minLevelController.text),
    );

    if (_batteryState == state) return;

    setState(() {
      _batteryState = state;
    });
  }

  Future<void> _showNotificationWithNoTitle({required int level, int max = 99, min = 30}) async {
    await flutterLocalNotificationsPlugin.cancel(0);

    MacOSNotificationDetails macosPlatformChannelSpecifics = MacOSNotificationDetails(
      subtitle: 'Current Battery Level: $level%',
      presentAlert: true,
      presentSound: true,
      presentBadge: true,
    );

    NotificationDetails platformChannelSpecifics = NotificationDetails(macOS: macosPlatformChannelSpecifics);

    var message = 'Battery Level: $level%';

    if (level >= max) {
      message = 'Battery Level: $level% - Please unplug the charger';

      flutterLocalNotificationsPlugin.show(
        0,
        'Warning',
        message,
        platformChannelSpecifics,
      );
    } else if (level <= min) {
      message = 'Battery Level: $level% - Please plug the charger';

      flutterLocalNotificationsPlugin.show(
        0,
        'Warning',
        message,
        platformChannelSpecifics,
      );
    }
  }

  Future<void> _storeBatteryPercentage() async {
    var box = await Hive.openBox('myBox');
    int? sMax = box.get('max');
    if (sMax != null) {
      debugPrint('have');
      _maxLevelController.text = sMax.toString();
      _minLevelController.text = box.get('min').toString();
    } else {
      box.put('max', int.parse(_maxLevelController.text));
      box.put('min', int.parse(_minLevelController.text));
      debugPrint('do not have');
    }
    
  }

  @override
  void dispose() {
    super.dispose();
    if (_batteryStateSubscription != null) {
      _batteryStateSubscription!.cancel();
    }
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
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // battery info
            Text('Batter Level: $_batterLevel'),

            // max level
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Set Max Warning Level',
                ),
                controller: _maxLevelController,
                onChanged: (value)  async{
                   var box = await Hive.openBox('myBox');
                    box.put('max', int.parse(value));
                },
              ),
            ),

            // min level
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                keyboardType: TextInputType.number,
                controller: _minLevelController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Set Min Warning Level',
                ),
                onChanged: (value)  async{
                   var box = await Hive.openBox('myBox');
                    box.put('min', int.parse(value));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // end
}
