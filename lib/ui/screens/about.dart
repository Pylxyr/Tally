import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme.dart';
import '../widgets/common.dart';

const String _repoUrl = 'https://github.com/Pylxyr/Tally';

/// Route to the About page: a short fade and lift, instant under reduce-motion.
Route<void> aboutRoute(BuildContext context) {
  final duration = motion(context, 360);
  return PageRouteBuilder<void>(
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    pageBuilder: (context, animation, secondaryAnimation) =>
        const AboutScreen(),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  Future<void> _openRepo() async {
    final messenger = ScaffoldMessenger.of(context);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(_repoUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      opened = false;
    }
    if (!opened) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open the link')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
          children: [
            StaggerIn(
              index: 0,
              child: Column(
                children: [
                  ExcludeSemantics(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: motion(context, 700),
                      curve: Curves.elasticOut,
                      builder: (context, t, child) => Transform.scale(
                        scale: t.clamp(0.0, 1.4),
                        child: child,
                      ),
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(32),
                        ),
                        child: Icon(
                          Icons.savings_rounded,
                          size: 48,
                          color: cs.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text('Tally', style: text.headlineMedium),
                  ),
                  const SizedBox(height: 4),
                  FutureBuilder<PackageInfo>(
                    future: _info,
                    builder: (context, snapshot) {
                      final info = snapshot.data;
                      final label = info != null
                          ? 'Version ${info.version} (${info.buildNumber})'
                          : snapshot.hasError
                          ? 'Version unavailable'
                          : 'Version';
                      return Text(
                        label,
                        style: text.bodyLarge?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontFeatures: tabularFigures,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            StaggerIn(
              index: 1,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'A private expense and budget tracker. Everything stays on '
                    'your device. There are no accounts, and the app does not '
                    'ask for internet access.',
                    style: text.bodyLarge,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            StaggerIn(
              index: 2,
              child: Card(
                child: ListTile(
                  minTileHeight: 64,
                  leading: const Icon(Icons.code_rounded),
                  title: const Text('View on GitHub'),
                  subtitle: const Text('github.com/Pylxyr/Tally'),
                  trailing: const Icon(Icons.open_in_new_rounded),
                  onTap: _openRepo,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
