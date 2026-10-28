/// Названия зон боли. Сохраняются как есть в `localization` через `, `,
/// поэтому все вместе укладываются в лимит backend (120 символов).
///
/// «Левый» и «правый» — стороны самого пациента: на виде спереди его правая
/// сторона слева на схеме.
abstract final class PainZones {
  static const crown = 'Темя';
  static const forehead = 'Лоб';
  static const rightTemple = 'Правый висок';
  static const leftTemple = 'Левый висок';
  static const rightEye = 'Правый глаз';
  static const leftEye = 'Левый глаз';
  static const sinuses = 'Пазухи';
  static const occiput = 'Затылок';
  static const neck = 'Шея';
  static const wholeHead = 'Вся голова';

  /// Зоны, которые видны на схеме спереди, сверху вниз.
  static const front = [
    forehead,
    crown,
    rightTemple,
    leftTemple,
    rightEye,
    leftEye,
    sinuses,
  ];

  /// Зоны, которые видны на схеме сзади.
  static const back = [crown, occiput, neck];

  static const all = [
    forehead,
    crown,
    rightTemple,
    leftTemple,
    rightEye,
    leftEye,
    sinuses,
    occiput,
    neck,
    wholeHead,
  ];
}
