import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:transconnect/core/services/auth_service.dart';
import 'package:transconnect/core/services/shared_preferences_service.dart';
import 'package:transconnect/features/community/services/community_service.dart';
import 'package:transconnect/navigation/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  await SharedPreferencesService().init();
  final authService = AuthService();
  await authService.init();

  // Initialize AppRouter
  final appRouter = AppRouter(authService: authService);

  runApp(MyApp(appRouter: appRouter, authService: authService));
}

class MyApp extends StatelessWidget {
  final AppRouter appRouter;
  final AuthService authService;

  const MyApp({super.key, required this.appRouter, required this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authService),
        Provider(create: (_) => appRouter),
        Provider(create: (_) => CommunityService(authService: authService)),
      ],
      child: MaterialApp.router(
        title: 'TransConnect',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        routerConfig: appRouter.router,
      ),
    );
  }
}
