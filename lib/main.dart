import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart' show DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:logging_appenders/logging_appenders.dart';
import 'package:mobile_nebula/screens/main_screen.dart';
import 'package:mobile_nebula/services/settings.dart';
import 'package:mobile_nebula/services/theme.dart';
import 'package:mobile_nebula/services/utils.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  PrintAppender.setupLogging();

  usePathUrlStrategy();
  runApp(Main());
}

//TODO: EventChannel might be better than the stream controller we are using now

class Main extends StatelessWidget {
  const Main({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => App();
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  AppState createState() => AppState();
}

class AppState extends State<App> {
  final settings = Settings();
  Brightness brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
  StreamController dnEnrolled = StreamController.broadcast();

  @override
  void initState() {
    //TODO: wait until settings is ready?
    settings.onChange().listen((_) {
      setState(() {
        if (settings.useSystemColors) {
          brightness = SchedulerBinding.instance.platformDispatcher.platformBrightness;
        } else {
          brightness = settings.darkMode ? Brightness.dark : Brightness.light;
        }
      });
    });

    // Listen to changes to the system brightness mode, update accordingly
    final dispatcher = SchedulerBinding.instance.platformDispatcher;
    dispatcher.onPlatformBrightnessChanged = () {
      if (settings.useSystemColors) {
        setState(() {
          brightness = dispatcher.platformBrightness;
        });
      }
    };

    super.initState();
  }

  @override
  void dispose() {
    dnEnrolled.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    TextTheme textTheme = Utils.createTextTheme();
    MaterialTheme theme = MaterialTheme(textTheme);

    return MaterialApp(
      navigatorKey: navigatorKey,
      scrollBehavior: const MaterialScrollBehavior().copyWith(physics: const ClampingScrollPhysics()),
      debugShowCheckedModeBanner: false,
      localizationsDelegates: <LocalizationsDelegate<dynamic>>[
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
        DefaultCupertinoLocalizations.delegate,
      ],
      title: 'Nebula',
      themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
      theme: theme.light().copyWith(
        splashFactory: Platform.isIOS ? NoSplash.splashFactory : null,
        highlightColor: Platform.isIOS ? Colors.black.withValues(alpha: 0.2) : null,
      ),
      darkTheme: theme.dark().copyWith(
        splashFactory: Platform.isIOS ? NoSplash.splashFactory : null,
        highlightColor: Platform.isIOS ? Colors.white.withValues(alpha: 0.2) : null,
      ),
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => MainScreen(dnEnrolled));
        }

        return null;
      },
    );
  }
}
