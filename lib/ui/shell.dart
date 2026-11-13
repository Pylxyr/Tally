import 'package:material_ui/material_ui.dart';

import '../state/app_state.dart';
import 'screens/budgets.dart';
import 'screens/dashboard.dart';
import 'screens/settings.dart';
import 'screens/tracker.dart';
import 'sheets/txn_sheet.dart';
import 'widgets/common.dart';

/// The main screen: four tabs and an Add button within thumb reach.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;

  /// Bumped on every tab change so Home and Budgets replay their entrance.
  int _epoch = 0;

  void _go(int i) {
    if (i == _index) return;
    setState(() {
      _index = i;
      _epoch++;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final state = AppScope.read(context);
      if (state.recoveredFromCorruption) {
        state.recoveredFromCorruption = false;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text(
              'Your saved data could not be read, so Tally started fresh. The old file was kept on the phone.',
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Pick up a new day, and add any recurring bills that have come due.
    if (lifecycle == AppLifecycleState.resumed && mounted) {
      AppScope.read(context).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _go(0);
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            DashboardScreen(onOpenTracker: () => _go(1), epoch: _epoch),
            TabReveal(active: _index == 1, child: const TrackerScreen()),
            BudgetsScreen(epoch: _epoch),
            TabReveal(active: _index == 3, child: const SettingsScreen()),
          ],
        ),
        floatingActionButton: _index < 2
            ? FloatingActionButton.extended(
                onPressed: () => showTxnSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add'),
              )
            : null,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Tracker',
            ),
            NavigationDestination(
              icon: Icon(Icons.pie_chart_outline_rounded),
              selectedIcon: Icon(Icons.pie_chart_rounded),
              label: 'Budgets',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
