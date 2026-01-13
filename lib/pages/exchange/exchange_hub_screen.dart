import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:transconnect/pages/community/mutual_aid_screen.dart';
import 'package:transconnect/pages/exchange/work_and_services_screen.dart';

class ExchangeHubScreen extends StatelessWidget {
  final int initialTabIndex;

  const ExchangeHubScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Exchange Hub'),
          actions: [
            IconButton(
              tooltip: 'Listings',
              icon: const Icon(Icons.list_alt_outlined),
              onPressed: () {
                context.push('/exchange/help');
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.handshake_outlined), text: 'Help'),
              Tab(icon: Icon(Icons.storefront_outlined), text: 'Work & Services'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MutualAidContent(),
            WorkAndServicesScreen(),
          ],
        ),
      ),
    );
  }
}
