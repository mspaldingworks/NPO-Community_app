import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/navigation/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferencesService().init();
  final authService = AuthService();
  await authService.init(); // Initialize the auth service
  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  const MyApp({super.key, required this.authService});

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter(authService: authService);

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
      ],
      child: MaterialApp.router(
        routerConfig: appRouter.router,
        title: 'TransConnect',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
      ),
    );
  }
}
