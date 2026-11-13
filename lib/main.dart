import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'state/app_state.dart';
import 'ui/screens/onboarding.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final state = await AppState.load();
  runApp(TallyApp(state: state));
}

class TallyApp extends StatelessWidget {
  const TallyApp({super.key, required this.state});

  final AppState state;

  static ThemeMode _modeFor(String key) {
    switch (key) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Tally',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: _modeFor(state.settings.themeModeKey),
          builder: (context, child) {
            final dark = Theme.of(context).brightness == Brightness.dark;
            final icons = dark ? Brightness.light : Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
                statusBarIconBrightness: icons,
                systemNavigationBarIconBrightness: icons,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          home: const _Root(),
        ),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return state.settings.onboarded ? const Shell() : const OnboardingPage();
  }
}
