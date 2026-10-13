import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';

enum HeadView { front, back }

/// An interactive Flutter schematic; replace its artwork when Figma source
/// assets are available. Coordinates are independent of the display size.
class PainHeadMap extends StatelessWidget {
  const PainHeadMap({
    required this.view,
    required this.selectedZones,
    required this.onToggle,
    super.key,
  });

  final HeadView view;
  final Set<String> selectedZones;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final regions = _regions(view);
    return AspectRatio(
      aspectRatio: 240 / 286,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaleX = constraints.maxWidth / 240;
          final scaleY = constraints.maxHeight / 286;
          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _HeadPainter(view, selectedZones),
                ),
              ),
              for (final region in regions)
                Positioned.fromRect(
                  rect: Rect.fromLTRB(
                    region.path.getBounds().left * scaleX,
                    region.path.getBounds().top * scaleY,
                    region.path.getBounds().right * scaleX,
                    region.path.getBounds().bottom * scaleY,
                  ),
                  child: Semantics(
                    button: true,
                    selected: selectedZones.contains(region.zone),
                    label: region.accessibleLabel,
                    hint: 'Нажмите, чтобы выбрать или убрать зону боли',
                    child: ClipPath(
                      clipper: _RegionClipper(region.path),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          key: ValueKey('pain-zone-${region.id}'),
                          onTap: () => onToggle(region.zone),
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HeadRegion {
  const _HeadRegion(this.id, this.zone, this.accessibleLabel, this.path);

  final String id;
  final String zone;
  final String accessibleLabel;
  final Path path;
}

List<_HeadRegion> _regions(HeadView view) {
  final crown = Path()
    ..moveTo(58, 86)
    ..lineTo(58, 78)
    ..cubicTo(58, 43, 82, 28, 120, 28)
    ..cubicTo(158, 28, 182, 43, 182, 78)
    ..lineTo(182, 86)
    ..quadraticBezierTo(120, 96, 58, 86)
    ..close();

  if (view == HeadView.back) {
    return [
      _HeadRegion('crown', 'Темя', 'Темя', crown),
      _HeadRegion(
        'occiput',
        'Затылок',
        'Затылок',
        Path()
          ..moveTo(62, 108)
          ..quadraticBezierTo(120, 120, 178, 108)
          ..cubicTo(178, 158, 150, 205, 120, 205)
          ..cubicTo(90, 205, 62, 158, 62, 108)
          ..close(),
      ),
    ];
  }

  return [
    _HeadRegion('forehead', 'Лоб', 'Лоб', crown),
    _HeadRegion(
      'left-temple',
      'Виски',
      'Виски, слева на схеме',
      Path()
        ..moveTo(58, 90)
        ..lineTo(80, 94)
        ..lineTo(77, 153)
        ..lineTo(66, 163)
        ..quadraticBezierTo(56, 133, 58, 90)
        ..close(),
    ),
    _HeadRegion(
      'right-temple',
      'Виски',
      'Виски, справа на схеме',
      Path()
        ..moveTo(182, 90)
        ..lineTo(160, 94)
        ..lineTo(163, 153)
        ..lineTo(174, 163)
        ..quadraticBezierTo(184, 133, 182, 90)
        ..close(),
    ),
  ];
}

class _RegionClipper extends CustomClipper<Path> {
  _RegionClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) {
    final bounds = path.getBounds();
    return path.shift(-bounds.topLeft).transform(Float64List.fromList([
      size.width / bounds.width, 0, 0, 0,
      0, size.height / bounds.height, 0, 0,
      0, 0, 1, 0,
      0, 0, 0, 1,
    ]));
  }

  @override
  bool shouldReclip(_RegionClipper oldClipper) => true;
}

class _HeadPainter extends CustomPainter {
  _HeadPainter(this.view, Set<String> selected)
      : selected = Set.unmodifiable(selected);

  final HeadView view;
  final Set<String> selected;

  static const _fill = Color(0xFFDDE7F2);
  static const _outline = Color(0xFFAFBFD1);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 240, size.height / 286);
    final outline = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawOval(
      const Rect.fromLTWH(25, 270, 190, 12),
      Paint()..color = const Color(0xFFF0F3F8),
    );
    final shoulders = Path()
      ..moveTo(31, 272)
      ..quadraticBezierTo(37, 251, 95, 242)
      ..lineTo(97, 191)
      ..lineTo(143, 191)
      ..lineTo(145, 242)
      ..quadraticBezierTo(203, 251, 209, 272)
      ..close();
    canvas.drawPath(shoulders, Paint()..color = _fill);
    canvas.drawPath(shoulders, outline);

    for (final ear in [
      const Rect.fromLTWH(49, 107, 17, 45),
      const Rect.fromLTWH(174, 107, 17, 45),
    ]) {
      canvas.drawOval(ear, Paint()..color = _fill);
      canvas.drawOval(ear, outline);
    }

    final head = Path()
      ..moveTo(120, 28)
      ..cubicTo(82, 28, 58, 43, 58, 78)
      ..lineTo(58, 99)
      ..cubicTo(55, 135, 70, 172, 92, 193)
      ..quadraticBezierTo(120, 217, 148, 193)
      ..cubicTo(170, 172, 185, 135, 182, 99)
      ..lineTo(182, 78)
      ..cubicTo(182, 43, 158, 28, 120, 28)
      ..close();
    canvas.drawPath(head, Paint()..color = _fill);
    for (final region in _regions(view)) {
      canvas.drawPath(
        region.path,
        Paint()
          ..color = selected.contains(region.zone)
              ? AppColors.blue
              : const Color(0xFFD3E0EE),
      );
      canvas.drawPath(region.path, outline);
    }
    canvas.drawPath(head, outline);

    if (view == HeadView.front) {
      final features = Path()
        ..moveTo(82, 110)
        ..quadraticBezierTo(94, 103, 107, 109)
        ..moveTo(133, 109)
        ..quadraticBezierTo(146, 103, 158, 110)
        ..moveTo(85, 121)
        ..quadraticBezierTo(96, 116, 106, 121)
        ..moveTo(134, 121)
        ..quadraticBezierTo(144, 116, 155, 121)
        ..moveTo(120, 118)
        ..lineTo(115, 148)
        ..quadraticBezierTo(120, 153, 126, 148)
        ..moveTo(105, 168)
        ..quadraticBezierTo(120, 175, 135, 168)
        ..moveTo(113, 178)
        ..quadraticBezierTo(120, 181, 127, 178);
      canvas.drawPath(features, outline);
    } else {
      final backLines = Path()
        ..moveTo(79, 104)
        ..quadraticBezierTo(74, 151, 99, 182)
        ..moveTo(161, 104)
        ..quadraticBezierTo(166, 151, 141, 182)
        ..moveTo(101, 219)
        ..quadraticBezierTo(120, 225, 139, 219);
      canvas.drawPath(backLines, outline);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeadPainter oldDelegate) =>
      oldDelegate.view != view ||
      !setEquals(oldDelegate.selected, selected);
}
