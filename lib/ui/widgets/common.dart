import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../logic/models.dart';
import '../../state/app_state.dart';
import '../theme.dart';

/// Digits that line up in columns, so amounts do not jiggle as they change.
const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

IconData categoryIcon(String key) {
  switch (key) {
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'grocery':
      return Icons.shopping_basket_rounded;
    case 'transport':
      return Icons.directions_bus_rounded;
    case 'bolt':
      return Icons.bolt_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'health':
      return Icons.favorite_rounded;
    case 'shopping':
      return Icons.shopping_bag_rounded;
    case 'fun':
      return Icons.local_activity_rounded;
    case 'travel':
      return Icons.flight_rounded;
    case 'wallet':
      return Icons.account_balance_wallet_rounded;
    case 'work':
      return Icons.work_rounded;
    case 'gift':
      return Icons.card_giftcard_rounded;
    default:
      return Icons.sell_rounded;
  }
}

/// Round badge showing a category's icon in its colour.
class CategoryAvatar extends StatelessWidget {
  const CategoryAvatar({super.key, required this.category, this.size = 44});

  final Category category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = Color(category.colorValue);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          shape: BoxShape.circle,
        ),
        child: Icon(
          categoryIcon(category.iconKey),
          size: size * 0.5,
          color: Color.lerp(color, cs.onSurface, 0.3),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(text, style: Theme.of(context).textTheme.titleLarge),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: motion(context, 700),
              curve: Curves.elasticOut,
              builder: (context, t, child) =>
                  Transform.scale(scale: t.clamp(0.0, 1.4), child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: cs.onPrimaryContainer),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(title, style: text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            message,
            style: text.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          if (actions.isNotEmpty) const SizedBox(height: 20),
          for (final a in actions)
            Padding(padding: const EdgeInsets.only(top: 8), child: a),
        ],
      ),
    );
  }
}

/// Wraps content for a modal bottom sheet: scrolls, clears the keyboard and
/// the system navigation bar.
class SheetBody extends StatelessWidget {
  const SheetBody({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + media.viewInsets.bottom + media.padding.bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

Future<T?> showSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// Keeps amounts to digits with up to two decimals. A comma becomes a point.
class AmountInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(',', '.');
    if (text.isEmpty) return newValue.copyWith(text: text);
    if (RegExp(r'^\d{0,10}(\.\d{0,2})?$').hasMatch(text)) {
      return newValue.copyWith(text: text);
    }
    return oldValue;
  }
}

/// A big amount field with the currency symbol in front.
class AmountField extends StatelessWidget {
  const AmountField({
    super.key,
    required this.controller,
    required this.symbol,
    this.autofocus = false,
    this.errorText,
    this.onChanged,
    this.label = 'Amount',
  });

  final TextEditingController controller;
  final String symbol;
  final bool autofocus;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final String label;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.displaySmall
        ?.copyWith(fontFeatures: tabularFigures, fontSize: 38);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      style: style,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [AmountInputFormatter()],
      decoration: fieldDecoration(
        context,
        label: label,
        hint: '0',
        prefixText: '$symbol ',
        errorText: errorText,
      ).copyWith(prefixStyle: style),
    );
  }
}

/// A small entrance animation for a row that was just added by a tap.
class JustAdded extends StatelessWidget {
  const JustAdded({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: motion(context, 320),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: t,
          child: Opacity(opacity: t, child: child),
        ),
      ),
      child: child,
    );
  }
}

/// One transaction row, shared by the dashboard and the tracker.
class TxnTile extends StatelessWidget {
  const TxnTile({super.key, required this.txn, required this.onTap});

  final Txn txn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cat = state.categoryFor(txn);
    final isIncome = txn.kind == TxnKind.income;
    final hasNote = txn.note.trim().isNotEmpty;
    final title = hasNote ? txn.note.trim() : cat.name;
    final subtitle = [
      if (hasNote) cat.name,
      if (txn.recurringId != null) 'Recurring',
    ].join(' \u00B7 ');
    final amount = state.money(txn.amountCents, showPlus: isIncome);
    return Semantics(
      button: true,
      onTap: onTap,
      label:
          '${isIncome ? 'Income' : 'Expense'}, $title, ${cat.name}, $amount. Tap to edit.',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                CategoryAvatar(category: cat),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  amount,
                  style: text.titleMedium?.copyWith(
                    fontFeatures: tabularFigures,
                    color: isIncome ? cs.primary : cs.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Confirmation dialog. Returns true when the person confirms.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(64, 48),
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Slides and fades its child in once, a moment after it first appears.
/// Give it a new key to play the entrance again (the Home and Budgets tabs do
/// this each time they are opened). [index] staggers siblings.
class StaggerIn extends StatefulWidget {
  const StaggerIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggerIn> createState() => _StaggerInState();
}

class _StaggerInState extends State<StaggerIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 560),
  );
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      return;
    }
    _timer = Timer(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 32),
            child: child,
          ),
        );
      },
    );
  }
}

/// Fades and lifts a whole tab each time it becomes the selected one, without
/// rebuilding it (so scroll position and search text are kept).
class TabReveal extends StatefulWidget {
  const TabReveal({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  State<TabReveal> createState() => _TabRevealState();
}

class _TabRevealState extends State<TabReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    value: 1,
  );

  @override
  void didUpdateWidget(TabReveal old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (MediaQuery.disableAnimationsOf(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 24),
            child: child,
          ),
        );
      },
    );
  }
}

/// Wraps [items] so they rise in one after another. Change [epoch] to replay.
List<Widget> staggered(String prefix, int epoch, List<Widget> items) {
  return [
    for (var i = 0; i < items.length; i++)
      StaggerIn(
        key: ValueKey('$prefix-$i-$epoch'),
        index: i < 6 ? i : 6,
        child: items[i],
      ),
  ];
}
