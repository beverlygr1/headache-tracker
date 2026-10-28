import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Круглое фото профиля; без фото — первая буква имени или значок.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    required this.name,
    this.photo,
    this.size = 62,
    super.key,
  });

  final String? name;
  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name?.trim() ?? '';
    final photo = this.photo;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
      child: photo != null
          ? Image.memory(
              photo,
              key: const ValueKey('profile-avatar-photo'),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  _Placeholder(initial: initial, size: size),
            )
          : _Placeholder(initial: initial, size: size),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.initial, required this.size});

  final String initial;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: initial.isEmpty
          ? Icon(
              Icons.person_outline_rounded,
              color: AppColors.ink,
              size: size * 0.4,
            )
          : Text(
              initial.characters.first.toUpperCase(),
              style: TextStyle(
                color: AppColors.ink,
                fontSize: size * 0.28,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}
