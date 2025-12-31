import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  void _handleLogin() {
    context.read<AuthCubit>().login(
      context.read<AuthCubit>().urlCtrl.text,
      context.read<AuthCubit>().userCtrl.text,
      context.read<AuthCubit>().passCtrl.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is AuthError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message)));
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
            ),
          ),
          child: Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width < 360
                  ? double.infinity
                  : MediaQuery.of(context).size.width * 0.8,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.download_for_offline,
                          size: 64,
                          color: Colors.teal,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          "Jellyfin Access",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: context.read<AuthCubit>().urlCtrl,
                          decoration: const InputDecoration(
                            labelText: "Server URL",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.link),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: context.read<AuthCubit>().userCtrl,
                          decoration: const InputDecoration(
                            labelText: "Username",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: context.read<AuthCubit>().passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Password",
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                        ),
                        const SizedBox(height: 24),
                        BlocBuilder<AuthCubit, AuthState>(
                          builder: (context, state) {
                            if (state is AuthLoading) {
                              return const CircularProgressIndicator();
                            }
                            return SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _handleLogin,
                                child: const Text("Connect"),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
