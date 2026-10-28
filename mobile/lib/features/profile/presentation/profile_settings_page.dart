import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/utils/russian_date.dart';
import '../../auth/state/auth_controller.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../../tracker/state/tracker_controller.dart';
import 'profile_avatar.dart';

/// Выбор фото: галерея или камера. Возвращает байты или `null` при отмене.
typedef PhotoPicker = Future<Uint8List?> Function(ImageSource source);

Future<Uint8List?> _pickPhoto(ImageSource source) async {
  // 512 px и JPEG-сжатие: фото весит десятки КБ и укладывается в лимит 2 МБ.
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );
  return file?.readAsBytes();
}

Future<String?> _deviceTimeZone() async =>
    (await FlutterTimezone.getLocalTimezone()).identifier;

const _genders = {'female': 'Женский', 'male': 'Мужской'};

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({
    super.key,
    required this.controller,
    this.pickPhoto = _pickPhoto,
    this.deviceTimeZone = _deviceTimeZone,
  });
  final AuthController controller;
  final PhotoPicker pickPhoto;
  final Future<String?> Function() deviceTimeZone;
  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  final _nameKey = GlobalKey<FormState>(),
      _passwordKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  final _current = TextEditingController(),
      _password = TextEditingController(),
      _confirm = TextEditingController();
  bool _savingName = false, _savingPassword = false, _showPasswords = false;
  bool _savingPhoto = false, _savingPersonal = false;
  String? _nameError, _passwordError, _photoError, _personalError;
  DateTime? _birthDate;
  String? _gender, _timeZone;
  bool get _busy =>
      _savingName || _savingPassword || _savingPhoto || _savingPersonal;
  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _birthDate = profile?.birthDate;
    _gender = _genders.containsKey(profile?.gender) ? profile?.gender : null;
    _timeZone = profile?.timeZone;
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Выбрать из галереи'),
              onTap: () => Navigator.pop(context, ImageSource.gallery)),
          // В браузере камера через image_picker недоступна.
          if (!kIsWeb)
            ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Сделать фото'),
                onTap: () => Navigator.pop(context, ImageSource.camera)),
        ]),
      ),
    );
    if (source == null || !mounted) return;

    final Uint8List? bytes;
    try {
      bytes = await widget.pickPhoto(source);
    } catch (_) {
      if (mounted) {
        setState(() => _photoError = 'Не удалось открыть фото. '
            'Проверьте доступ к камере или галерее.');
      }
      return;
    }
    if (bytes == null || !mounted) return;
    await _runPhoto(
        () => widget.controller.uploadAvatar(bytes!), 'Фото обновлено');
  }

  Future<void> _deletePhoto() =>
      _runPhoto(widget.controller.deleteAvatar, 'Фото удалено');

  Future<void> _runPhoto(Future<void> Function() action, String done) async {
    if (_busy) return;
    setState(() {
      _savingPhoto = true;
      _photoError = null;
    });
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (error) {
      if (mounted) setState(() => _photoError = describeError(error));
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Дата рождения',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  Future<void> _useDeviceTimeZone() async {
    try {
      final zone = await widget.deviceTimeZone();
      if (zone != null && zone.isNotEmpty && mounted) {
        setState(() => _timeZone = zone);
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _personalError = 'Не удалось определить часовой пояс телефона');
      }
    }
  }

  Future<void> _savePersonal() async {
    if (_busy) return;
    setState(() {
      _savingPersonal = true;
      _personalError = null;
    });
    try {
      await widget.controller.updatePersonal(
        birthDate: _birthDate,
        gender: _gender,
        timeZone: _timeZone,
      );
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Данные сохранены')));
      }
    } catch (error) {
      if (mounted) setState(() => _personalError = describeError(error));
    } finally {
      if (mounted) setState(() => _savingPersonal = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _current.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_busy || !_nameKey.currentState!.validate()) return;
    setState(() {
      _savingName = true;
      _nameError = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await widget.controller.updateName(_name.text);
      if (!mounted) return;
      _name.text = widget.controller.profile?.name ?? _name.text.trim();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Имя сохранено')));
    } catch (error) {
      if (mounted) setState(() => _nameError = describeError(error));
    } finally {
      if (mounted) setState(() => _savingName = false);
    }
  }

  Future<void> _savePassword() async {
    if (_busy || !_passwordKey.currentState!.validate()) return;
    setState(() {
      _savingPassword = true;
      _passwordError = null;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await widget.controller.changePassword(
          currentPassword: _current.text, newPassword: _password.text);
      if (!mounted) return;
      _current.clear();
      _password.clear();
      _confirm.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Пароль изменён')));
    } catch (error) {
      if (mounted) setState(() => _passwordError = describeError(error));
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const BackTitleBar(title: 'Настройки профиля'),
        body: SafeArea(
            top: false,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              children: [
                ListenableBuilder(
                    listenable: widget.controller,
                    builder: (context, _) => _photoCard()),
                const SizedBox(height: 18),
                AppCard(
                    child: Form(
                        key: _nameKey,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Как к вам обращаться?',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 14),
                              TextFormField(
                                  key: const ValueKey('profile-name'),
                                  controller: _name,
                                  enabled: !_busy,
                                  maxLength: 120,
                                  textCapitalization: TextCapitalization.words,
                                  textInputAction: TextInputAction.done,
                                  decoration:
                                      const InputDecoration(labelText: 'Имя'),
                                  onFieldSubmitted: (_) => _saveName(),
                                  validator: (value) =>
                                      value == null || value.trim().isEmpty
                                          ? 'Укажите имя'
                                          : null),
                              if (_nameError != null)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(_nameError!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error))),
                              PrimaryActionButton(
                                  label: _savingName
                                      ? 'Сохранение…'
                                      : 'Сохранить имя',
                                  onPressed: _busy ? null : _saveName),
                            ]))),
                const SizedBox(height: 18),
                _personalCard(),
                const SizedBox(height: 18),
                AppCard(
                    child: Form(
                        key: _passwordKey,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Смена пароля',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 8),
                              const Text(
                                  'После смены пароля остальные сеансы будут завершены.',
                                  style: TextStyle(
                                      color: AppColors.muted, fontSize: 11)),
                              const SizedBox(height: 14),
                              _passwordField(
                                  'current-password',
                                  'Текущий пароль',
                                  _current,
                                  (value) => value == null || value.isEmpty
                                      ? 'Введите текущий пароль'
                                      : null,
                                  AutofillHints.password),
                              const SizedBox(height: 12),
                              _passwordField(
                                  'new-password', 'Новый пароль', _password,
                                  (value) {
                                if (value == null ||
                                    value.length < 8 ||
                                    value.length > 128) {
                                  return 'От 8 до 128 символов';
                                }
                                if (value == _current.text) {
                                  return 'Новый пароль должен отличаться';
                                }
                                return null;
                              }, AutofillHints.newPassword),
                              const SizedBox(height: 12),
                              _passwordField(
                                  'confirm-password',
                                  'Повторите новый пароль',
                                  _confirm,
                                  (value) => value != _password.text ||
                                          value == null ||
                                          value.isEmpty
                                      ? 'Пароли не совпадают'
                                      : null,
                                  AutofillHints.newPassword),
                              Material(
                                  color: Colors.transparent,
                                  child: CheckboxListTile(
                                      contentPadding: EdgeInsets.zero,
                                      dense: true,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      value: _showPasswords,
                                      title: const Text('Показать пароли'),
                                      onChanged: _busy
                                          ? null
                                          : (value) => setState(() =>
                                              _showPasswords =
                                                  value ?? false))),
                              if (_passwordError != null)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(_passwordError!,
                                        style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error))),
                              PrimaryActionButton(
                                  label: _savingPassword
                                      ? 'Сохранение…'
                                      : 'Изменить пароль',
                                  onPressed: _busy ? null : _savePassword),
                            ]))),
              ],
            )),
      );

  Widget _photoCard() {
    final profile = widget.controller.profile;
    final hasPhoto = profile?.hasAvatar ?? false;
    return AppCard(
      child: Column(children: [
        ProfileAvatar(
          key: const ValueKey('settings-avatar'),
          name: profile?.name,
          photo: widget.controller.avatar,
          size: 96,
        ),
        const SizedBox(height: 10),
        Text(profile?.email ?? '',
            style: const TextStyle(color: AppColors.muted)),
        const SizedBox(height: 14),
        if (_photoError != null)
          Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_photoError!,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error))),
        PrimaryActionButton(
            label: _savingPhoto
                ? 'Сохранение…'
                : hasPhoto
                    ? 'Сменить фото'
                    : 'Добавить фото',
            icon: Icons.photo_camera_outlined,
            onPressed: _busy ? null : _choosePhoto),
        if (hasPhoto) ...[
          const SizedBox(height: 10),
          SecondaryActionButton(
              label: 'Удалить фото', onPressed: _busy ? null : _deletePhoto),
        ],
      ]),
    );
  }

  Widget _personalCard() => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Личные данные', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
              'Необязательно. Часовой пояс нужен для прогноза на завтра.',
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 8),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              key: const ValueKey('profile-birth-date'),
              contentPadding: EdgeInsets.zero,
              enabled: !_busy,
              leading: const Icon(Icons.cake_outlined),
              title: const Text('Дата рождения'),
              subtitle: Text(_birthDate == null
                  ? 'Не указана'
                  : '${RussianDate.dayMonth(_birthDate!)} ${_birthDate!.year}'),
              onTap: _pickBirthDate,
              trailing: _birthDate == null
                  ? null
                  : IconButton(
                      tooltip: 'Очистить дату',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _busy
                          ? null
                          : () => setState(() => _birthDate = null)),
            ),
          ),
          const SizedBox(height: 6),
          const Text('Пол',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            key: const ValueKey('profile-gender'),
            segments: [
              for (final entry in _genders.entries)
                ButtonSegment(value: entry.key, label: Text(entry.value)),
              const ButtonSegment(value: '', label: Text('Не указан')),
            ],
            selected: {_gender ?? ''},
            showSelectedIcon: false,
            onSelectionChanged: _busy
                ? null
                : (value) => setState(
                    () => _gender = value.first.isEmpty ? null : value.first),
          ),
          const SizedBox(height: 14),
          Material(
            type: MaterialType.transparency,
            child: ListTile(
              key: const ValueKey('profile-time-zone'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.public_rounded),
              title: const Text('Часовой пояс'),
              subtitle: Text(_timeZone ?? 'Не указан'),
              trailing: TextButton(
                  onPressed: _busy ? null : _useDeviceTimeZone,
                  child: const Text('Как на телефоне')),
            ),
          ),
          if (_personalError != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_personalError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error))),
          const SizedBox(height: 6),
          PrimaryActionButton(
              label: _savingPersonal ? 'Сохранение…' : 'Сохранить данные',
              onPressed: _busy ? null : _savePersonal),
        ]),
      );

  Widget _passwordField(
          String keyName,
          String label,
          TextEditingController controller,
          FormFieldValidator<String> validator,
          String autofillHint) =>
      TextFormField(
        key: ValueKey(keyName),
        controller: controller,
        validator: validator,
        enabled: !_busy,
        obscureText: !_showPasswords,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: [autofillHint],
        maxLength: 128,
        textInputAction: keyName == 'confirm-password'
            ? TextInputAction.done
            : TextInputAction.next,
        onFieldSubmitted:
            keyName == 'confirm-password' ? (_) => _savePassword() : null,
        decoration: InputDecoration(labelText: label, counterText: ''),
      );
}
