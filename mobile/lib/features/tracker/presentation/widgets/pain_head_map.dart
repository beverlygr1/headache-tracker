import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/pain_zones.dart';

enum HeadView { front, back }

/// Интерактивная схема головы. Координаты заданы в системе 240×286 и не
/// зависят от размера экрана.
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

  static const _width = 240.0;
  static const _height = 286.0;

  @override
  Widget build(BuildContext context) {
    final regions = _regionsFor(view);
    return AspectRatio(
      aspectRatio: _width / _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scaleX = constraints.maxWidth / _width;
          final scaleY = constraints.maxHeight / _height;
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
                    region.bounds.left * scaleX,
                    region.bounds.top * scaleY,
                    region.bounds.right * scaleX,
                    region.bounds.bottom * scaleY,
                  ),
                  child: Semantics(
                    button: true,
                    selected: selectedZones.contains(region.zone),
                    label: region.zone,
                    hint: 'Нажмите, чтобы выбрать или убрать зону боли',
                    // Нажатие засчитывается только внутри формы области.
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
  _HeadRegion(this.id, this.zone, this.path) : bounds = path.getBounds();

  final String id;
  final String zone;
  final Path path;
  final Rect bounds;
}

Path _intersect(Path a, Path b) => Path.combine(PathOperation.intersect, a, b);
Path _minus(Path a, Path b) => Path.combine(PathOperation.difference, a, b);

Path _frontHead() => Path()
  ..moveTo(120, 24)
  ..cubicTo(84, 24, 60, 46, 59, 84)
  ..cubicTo(58, 108, 60, 130, 66, 148)
  ..cubicTo(75, 176, 96, 204, 120, 206)
  ..cubicTo(144, 204, 165, 176, 174, 148)
  ..cubicTo(180, 130, 182, 108, 181, 84)
  ..cubicTo(180, 46, 156, 24, 120, 24)
  ..close();

Path _backHead() => Path()
  ..moveTo(120, 24)
  ..cubicTo(84, 24, 60, 46, 59, 86)
  ..cubicTo(58, 124, 66, 160, 86, 182)
  ..quadraticBezierTo(120, 200, 154, 182)
  ..cubicTo(174, 160, 182, 124, 181, 86)
  ..cubicTo(180, 46, 156, 24, 120, 24)
  ..close();

/// Верх головы одинаков на обоих видах: выбор «Темя» виден и спереди, и сзади.
Path _crownOf(Path head) => _intersect(
      head,
      Path()
        ..moveTo(0, 0)
        ..lineTo(240, 0)
        ..lineTo(240, 48)
        ..quadraticBezierTo(120, 66, 0, 48)
        ..close(),
    );

Rect _eye(double centerX) =>
    Rect.fromCenter(center: Offset(centerX, 117), width: 30, height: 18);

final _regionCache = <HeadView, List<_HeadRegion>>{};

List<_HeadRegion> _regionsFor(HeadView view) =>
    _regionCache.putIfAbsent(view, () => _buildRegions(view));

List<_HeadRegion> _buildRegions(HeadView view) {
  if (view == HeadView.back) {
    final head = _backHead();
    final crown = _crownOf(head);
    final neck = _minus(
      Path()
        ..moveTo(98, 176)
        ..lineTo(142, 176)
        ..lineTo(146, 238)
        ..quadraticBezierTo(120, 246, 94, 238)
        ..close(),
      head,
    );
    return [
      _HeadRegion('crown', PainZones.crown, crown),
      _HeadRegion('occiput', PainZones.occiput, _minus(head, crown)),
      _HeadRegion('neck', PainZones.neck, neck),
    ];
  }

  final head = _frontHead();
  final crown = _crownOf(head);
  final forehead = _minus(
    _intersect(
      head,
      Path()
        ..moveTo(84, 30)
        ..lineTo(156, 30)
        ..lineTo(156, 96)
        ..quadraticBezierTo(120, 104, 84, 96)
        ..close(),
    ),
    crown,
  );
  Path temple(List<Offset> points) {
    final raw = Path()..addPolygon(points, true);
    return _minus(_minus(_intersect(head, raw), crown), forehead);
  }

  final eyes = Path()
    ..addOval(_eye(100))
    ..addOval(_eye(140));
  final sinuses = _minus(
    _minus(
      _intersect(
        head,
        Path()
          ..addRRect(
              RRect.fromLTRBR(86, 106, 154, 160, const Radius.circular(16))),
      ),
      eyes,
    ),
    forehead,
  );

  return [
    _HeadRegion('crown', PainZones.crown, crown),
    _HeadRegion('forehead', PainZones.forehead, forehead),
    // Вид спереди: правая сторона пациента — слева на схеме.
    _HeadRegion(
      'right-temple',
      PainZones.rightTemple,
      temple(const [
        Offset(0, 40),
        Offset(84, 52),
        Offset(84, 96),
        Offset(78, 140),
        Offset(0, 150),
      ]),
    ),
    _HeadRegion(
      'left-temple',
      PainZones.leftTemple,
      temple(const [
        Offset(240, 40),
        Offset(156, 52),
        Offset(156, 96),
        Offset(162, 140),
        Offset(240, 150),
      ]),
    ),
    // Мелкие зоны идут последними — поверх крупных: нажатие в глаз всегда
    // достаётся глазу, а не окружающим пазухам с вырезом под него.
    _HeadRegion('sinuses', PainZones.sinuses, sinuses),
    _HeadRegion('right-eye', PainZones.rightEye, Path()..addOval(_eye(100))),
    _HeadRegion('left-eye', PainZones.leftEye, Path()..addOval(_eye(140))),
  ];
}

class _RegionClipper extends CustomClipper<Path> {
  _RegionClipper(this.path);

  final Path path;

  @override
  Path getClip(Size size) {
    final bounds = path.getBounds();
    return path.shift(-bounds.topLeft).transform(Float64List.fromList([
          size.width / bounds.width,
          0,
          0,
          0,
          0,
          size.height / bounds.height,
          0,
          0,
          0,
          0,
          1,
          0,
          0,
          0,
          0,
          1,
        ]));
  }

  @override
  bool shouldReclip(_RegionClipper oldClipper) => oldClipper.path != path;
}

class _HeadPainter extends CustomPainter {
  _HeadPainter(this.view, Set<String> selected)
      : selected = Set.unmodifiable(selected);

  final HeadView view;
  final Set<String> selected;

  static const _skin = Color(0xFFE6EEF7);
  static const _region = Color(0xFFD3E1F0);
  static const _selected = Color(0xE63D8BF2);
  // «Вся голова»: светло-синяя заливка всей головы, отдельные зоны ярче.
  static const _wholeHeadSkin = Color(0xFFC6DCFA);
  static const _wholeHeadRegion = Color(0xFFA7C9F7);
  static const _outline = Color(0xFF9FB3CA);
  static const _feature = Color(0xD96F84A0);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(
        size.width / PainHeadMap._width, size.height / PainHeadMap._height);

    final outline = Paint()
      ..color = _outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final separator = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    final feature = Paint()
      ..color = _feature
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Тень и плечи.
    canvas.drawOval(
      const Rect.fromLTWH(25, 270, 190, 12),
      Paint()..color = const Color(0xFFF0F3F8),
    );
    final shoulders = Path()
      ..moveTo(31, 272)
      ..quadraticBezierTo(37, 250, 92, 240)
      ..lineTo(98, 186)
      ..lineTo(142, 186)
      ..lineTo(148, 240)
      ..quadraticBezierTo(203, 250, 209, 272)
      ..close();
    canvas.drawPath(shoulders, Paint()..color = _skin);
    canvas.drawPath(shoulders, outline);

    for (final ear in const [
      Rect.fromLTWH(47, 98, 16, 42),
      Rect.fromLTWH(177, 98, 16, 42),
    ]) {
      canvas.drawOval(ear, Paint()..color = _skin);
      canvas.drawOval(ear, outline);
    }

    final whole = selected.contains(PainZones.wholeHead);
    final head = view == HeadView.front ? _frontHead() : _backHead();
    canvas.drawPath(head, Paint()..color = whole ? _wholeHeadSkin : _skin);

    for (final region in _regionsFor(view)) {
      final isSelected = selected.contains(region.zone);
      canvas.drawPath(
        region.path,
        Paint()
          ..color = isSelected
              ? _selected
              : whole
                  ? _wholeHeadRegion
                  : _region,
      );
      canvas.drawPath(region.path, separator);
    }
    canvas.drawPath(head, outline);

    if (view == HeadView.front) {
      final face = Path()
        // брови
        ..moveTo(86, 104)
        ..quadraticBezierTo(99, 98, 112, 103)
        ..moveTo(128, 103)
        ..quadraticBezierTo(141, 98, 154, 104)
        // глаза
        ..moveTo(91, 118)
        ..quadraticBezierTo(100, 112, 109, 118)
        ..moveTo(131, 118)
        ..quadraticBezierTo(140, 112, 149, 118)
        // нос
        ..moveTo(120, 112)
        ..lineTo(115, 146)
        ..quadraticBezierTo(120, 151, 126, 146)
        // рот
        ..moveTo(106, 172)
        ..quadraticBezierTo(120, 179, 134, 172);
      canvas.drawPath(face, feature);
    } else {
      final back = Path()
        // линия роста волос и позвоночник
        ..moveTo(78, 150)
        ..quadraticBezierTo(120, 168, 162, 150)
        ..moveTo(120, 196)
        ..lineTo(120, 236);
      canvas.drawPath(back, feature);
    }

    // Стороны пациента: спереди его правая сторона слева на схеме.
    final leftLabel = view == HeadView.front ? 'П' : 'Л';
    final rightLabel = view == HeadView.front ? 'Л' : 'П';
    _drawSide(canvas, leftLabel, const Offset(26, 112));
    _drawSide(canvas, rightLabel, const Offset(214, 112));

    canvas.restore();
  }

  void _drawSide(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: AppColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_HeadPainter oldDelegate) =>
      oldDelegate.view != view || !setEquals(oldDelegate.selected, selected);
}
