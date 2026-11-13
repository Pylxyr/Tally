import 'package:material_ui/material_ui.dart';

import '../../logic/money.dart';
import '../../state/app_state.dart';
import '../sheets/other_sheets.dart';
import '../widgets/common.dart';

/// First-run setup: currency and monthly budget.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final TextEditingController _budget = TextEditingController();
  String _currency = '\u20B1';
  String? _error;

  @override
  void dispose() {
    _budget.dispose();
    super.dispose();
  }

  void _finish({bool sample = false, bool skipBudget = false}) {
    final state = AppScope.read(context);
    var cents = 0;
    if (!skipBudget) {
      final parsed = parseCents(_budget.text);
      if (parsed != null && parsed > 0) {
        cents = parsed;
      } else if (!sample) {
        setState(() => _error = 'Enter your monthly budget, or skip for now');
        return;
      }
    }
    state.completeOnboarding(
      currency: _currency,
      budgetCents: cents,
      withSampleData: sample,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              children: staggered('welcome', 0, [
                ExcludeSemantics(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.donut_large_rounded,
                      color: cs.onPrimary,
                      size: 34,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Semantics(
                  header: true,
                  child: Text('Welcome to Tally', style: text.headlineMedium),
                ),
                const SizedBox(height: 8),
                Text(
                  'Know what you can still spend today. Your data stays on this phone: no accounts, no internet.',
                  style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                Text('Currency symbol', style: text.titleMedium),
                const SizedBox(height: 12),
                CurrencyPicker(
                  value: _currency,
                  onChanged: (v) => setState(() => _currency = v),
                ),
                const SizedBox(height: 28),
                AmountField(
                  controller: _budget,
                  symbol: _currency,
                  label: 'Monthly budget',
                  errorText: _error,
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: () => _finish(),
                  child: const Text('Get started'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _finish(sample: true),
                  child: const Text('Try it with sample data'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _finish(skipBudget: true),
                  child: const Text('Skip the budget for now'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
