import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.line,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontFamily: AppText.sans, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class TopicPill extends StatelessWidget {
  final String text;
  const TopicPill(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppText.sans,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

/// Thin progress bar made of [total] segments, the first [filled] in orange.
class SegmentBar extends StatelessWidget {
  final int filled;
  final int total;
  const SegmentBar({super.key, required this.filled, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < filled ? AppColors.orange : AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class StreakBadge extends StatelessWidget {
  final int days;
  const StreakBadge(this.days, {super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Streak $days',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_fire_department_outlined, size: 18, color: AppColors.orange),
            const SizedBox(width: 6),
            Text(
              '$days',
              style: const TextStyle(fontFamily: AppText.sans, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

/// The MorningFacts mark: a sunrise with rays above three text lines.
/// Drawn in code so it stays sharp at every size.
class SunMark extends StatelessWidget {
  final double size;
  const SunMark({super.key, this.size = 64});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _SunMarkPainter()),
  );
}

class _SunMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 160;
    canvas.scale(s);
    final orange = Paint()..color = AppColors.orange;
    canvas.drawArc(Rect.fromCircle(center: const Offset(80, 76), radius: 26), pi, pi, true, orange);
    final ray = Paint()
      ..color = AppColors.orange
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 5; i++) {
      final a = pi + pi * i / 4;
      final dy = (i == 0 || i == 4) ? -3.0 : 0.0;
      canvas.drawLine(
        Offset(80 + 34 * cos(a), 76 + 34 * sin(a) + dy),
        Offset(80 + 44 * cos(a), 76 + 44 * sin(a) + dy),
        ray,
      );
    }
    final ink = Paint()
      ..color = AppColors.ink
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(34, 92), const Offset(126, 92), ink);
    canvas.drawLine(const Offset(34, 108), const Offset(126, 108), ink);
    canvas.drawLine(const Offset(34, 124), const Offset(98, 124), ink);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
