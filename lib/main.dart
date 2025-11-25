import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:transconnect/core/services/http_overrides.dart';
import 'dart:io';
import 'package:transconnect/navigation/app_router.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  HttpOverrides.global = MyHttpOverrides();
  final savedThemeMode = await AdaptiveTheme.getThemeMode();
  runApp(MyApp(savedThemeMode: savedThemeMode));
=======
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/community_service.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/navigation/app_router.dart';
import 'package:transconnect/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesService().init();
  final sharedPreferences = await SharedPreferences.getInstance();
  runApp(MyApp(sharedPreferences: sharedPreferences));
>>>>>>> paige-working
}

class MyApp extends StatelessWidget {
  final SharedPreferences sharedPreferences;
  const MyApp({super.key, required this.sharedPreferences});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<SharedPreferences>.value(value: sharedPreferences),
        ChangeNotifierProvider<AuthService>(
          create: (context) => AuthService(),
        ),
        Provider<CommunityService>(
          create: (context) => CommunityService(),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authService = Provider.of<AuthService>(context, listen: false);
          final appRouter = AppRouter(authService: authService);

          return MaterialApp.router(
            title: 'TransConnect',
            theme: AppTheme.lightTheme,
            routerConfig: appRouter.router,
          );
        },
      ),
    );
  }
}
