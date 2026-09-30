import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../tracker/presentation/widgets/common.dart';
import '../../tracker/state/tracker_controller.dart';
import '../state/auth_controller.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({
    required this.controller,
    super.key,
  });

  final AuthController controller;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistration = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            final busy = widget.controller.isBusy;
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
                children: [
                  Text(
                    _isRegistration ? 'Регистрация' : 'Вход',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Дневник головной боли хранится в вашем аккаунте',
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 26),
                  AppCard(
                    child: Column(
                      children: [
                        if (_isRegistration) ...[
                          TextFormField(
                            controller: _nameController,
                            enabled: !busy,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(labelText: 'Имя'),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Введите имя'
                                    : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: _emailController,
                          enabled: !busy,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(labelText: 'Email'),
                          validator: (value) =>
                              (value == null || !value.contains('@'))
                                  ? 'Введите корректный email'
                                  : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _passwordController,
                          enabled: !busy,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration:
                              const InputDecoration(labelText: 'Пароль'),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Введите пароль';
                            }
                            if (_isRegistration && value.length < 8) {
                              return 'Минимум 8 символов';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryActionButton(
                    label: busy
                        ? 'Подождите…'
                        : _isRegistration
                            ? 'Создать аккаунт'
                            : 'Войти',
                    onPressed: busy ? null : _submit,
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(
                              () => _isRegistration = !_isRegistration,
                            ),
                    child: Text(
                      _isRegistration
                          ? 'Уже есть аккаунт? Войти'
                          : 'Нет аккаунта? Зарегистрироваться',
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    try {
      if (_isRegistration) {
        await widget.controller.register(
          name: _nameController.text.trim(),
          email: email,
          password: password,
        );
      } else {
        await widget.controller.login(email: email, password: password);
      }
    } catch (error) {
      if (mounted) showErrorSnackBar(context, describeError(error));
    }
  }
}
