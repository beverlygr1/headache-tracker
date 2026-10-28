import 'package:flutter/material.dart';

/// A compact input dialog also fits narrow screens when the keyboard is open.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required String helpText,
}) =>
    showTimePicker(
      context: context,
      initialTime: initialTime,
      initialEntryMode: TimePickerEntryMode.input,
      orientation: Orientation.portrait,
      helpText: helpText,
      cancelText: 'Отмена',
      confirmText: 'Сохранить',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
