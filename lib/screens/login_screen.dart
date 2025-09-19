import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:test_chat/services/matrix_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _homeserverController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  String? _error;

  @override
  void initState() {
    super.initState();
    _homeserverController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final service = context.read<MatrixService>();
    if (_homeserverController.text.isEmpty) {
      _homeserverController.text = service.homeserver;
    }
  }

  @override
  void dispose() {
    _homeserverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final service = context.read<MatrixService>();

    setState(() {
      _error = null;
    });
    await service.login(
      homeserver: _homeserverController.text,
      username: _usernameController.text,
      password: _passwordController.text,
    );
    if (!mounted) {
      return;
    }
    if (service.errorMessage != null && service.errorMessage!.isNotEmpty) {
      setState(() {
        _error = service.errorMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(service.errorMessage!)),
      );
    } else {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<MatrixService>();
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 6,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Matrix Chat 登入',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _homeserverController,
                      decoration: const InputDecoration(
                        labelText: 'Homeserver URL',
                        hintText: 'https://matrix.org',
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入 homeserver URL';
                        }
                        final uri = Uri.tryParse(value);
                        if (uri == null || !uri.hasScheme) {
                          return '請輸入合法的 URL';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Matrix 帳號 (不含 @)',
                      ),
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入帳號';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: '密碼',
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '請輸入密碼';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: const TextStyle(
                            color: Colors.red,
                          ),
                        ),
                      ),
                    FilledButton(
                      onPressed: service.isBusy ? null : _submit,
                      child: service.isBusy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('登入'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '輸入 Matrix 帳號即可連線至去中心化聊天服務。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
