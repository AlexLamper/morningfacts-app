import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../l10n.dart';
import '../services/purchases.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum _Plan { yearly, monthly, lifetime }

/// Soft paywall: closable, and the free daily fact always stays.
/// Prices come from RevenueCat when configured, else the planned prices.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  _Plan plan = _Plan.yearly;
  Offering? offering;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    PurchaseService.currentOffering().then((o) {
      if (mounted) setState(() => offering = o);
    });
  }

  Package? _package(_Plan p) => switch (p) {
    _Plan.yearly => offering?.annual,
    _Plan.monthly => offering?.monthly,
    _Plan.lifetime => offering?.lifetime,
  };

  String _price(_Plan p) {
    final pkg = _package(p);
    if (pkg != null) return pkg.storeProduct.priceString;
    return switch (p) {
      _Plan.yearly => '€29.99',
      _Plan.monthly => '€4.99',
      _Plan.lifetime => '€59.99',
    };
  }

  Future<void> _buy(String lang) async {
    final pkg = _package(plan);
    if (pkg == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(lang, 'purchaseFailed'))));
      return;
    }
    setState(() => busy = true);
    try {
      final ok = await PurchaseService.buy(pkg);
      if (ok) {
        ref.read(appProvider.notifier).setPremium(true);
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(lang, 'purchaseFailed'))));
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _restore() async {
    final ok = await PurchaseService.restore();
    if (ok) {
      ref.read(appProvider.notifier).setPremium(true);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appProvider).lang;
    String t(String k, [Map<String, Object> a = const {}]) => tr(lang, k, a);
    final period = {
      _Plan.yearly: lang == 'nl' ? ' / jaar' : ' / year',
      _Plan.monthly: lang == 'nl' ? ' / maand' : ' / month',
      _Plan.lifetime: lang == 'nl' ? ' eenmalig' : ' once',
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.muted),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(t('paywallLabel'), style: AppText.label.copyWith(color: AppColors.orange)),
                      const SizedBox(height: 8),
                      Text(t('paywallTitle'), style: AppText.display.copyWith(fontSize: 34)),
                      const SizedBox(height: 20),
                      for (final k in const ['feat1', 'feat2', 'feat3', 'feat4'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              const Icon(Icons.check, color: AppColors.orange, size: 20),
                              const SizedBox(width: 12),
                              Expanded(child: Text(t(k), style: AppText.body.copyWith(fontSize: 16))),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      for (final p in _Plan.values) ...[
                        _planTile(
                          name: t(p.name),
                          sub: p == _Plan.yearly ? t('yearlySub') : null,
                          price: '${_price(p)}${period[p]}',
                          best: p == _Plan.yearly ? t('bestValue') : null,
                          selected: plan == p,
                          onTap: () => setState(() => plan = p),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                label: plan == _Plan.yearly ? t('startTrial') : t('subscribe'),
                onPressed: busy ? null : () => _buy(lang),
              ),
              const SizedBox(height: 10),
              if (plan == _Plan.yearly)
                Text(
                  t('trialNote', {'price': _price(_Plan.yearly)}),
                  textAlign: TextAlign.center,
                  style: AppText.small,
                ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  TextButton(
                    onPressed: _restore,
                    child: Text(t('restore'), style: AppText.small),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t('keepFree'), style: AppText.small),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _planTile({
    required String name,
    String? sub,
    required String price,
    String? best,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: selected ? AppColors.ink : AppColors.line, width: selected ? 2 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: AppText.sans,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (best != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.orange,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  best,
                                  style: const TextStyle(
                                    fontFamily: AppText.sans,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.white,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (sub != null) ...[const SizedBox(height: 2), Text(sub, style: AppText.small)],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    price,
                    style: const TextStyle(fontFamily: AppText.sans, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
