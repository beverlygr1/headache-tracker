import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../auth/state/auth_controller.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../../tracker/state/tracker_controller.dart';

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key, required this.controller});
  final AuthController controller;
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
  String? _nameError, _passwordError;
  bool get _busy => _savingName || _savingPassword;
  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.controller.profile?.name ?? '');
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
                Text(widget.controller.profile?.email ?? '',
                    style: const TextStyle(color: AppColors.muted)),
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
