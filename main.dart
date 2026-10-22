
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF22D3EE),
          brightness: Brightness.dark,
        ),
      ),
      home: const LoginForm(),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF22D3EE),
          content: Text(
            'Welcome, ${_emailController.text.trim()}!',
            style: const TextStyle(color: Color(0xFF0F172A)),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            color: const Color(0xFF1E293B),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Login icon
                    const Icon(
                      Icons.lock_outline,
                      size: 75,
                      color: Color(0xFF22D3EE),
                    ),

                    const SizedBox(height: 20),

                    // Heading
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Login to your account',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),

                    const SizedBox(height: 30),

                    // Email field
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'Enter your email',
                        labelStyle: const TextStyle(
                          color: Color(0xFFCBD5E1),
                        ),
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Color(0xFF22D3EE),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF475569),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF22D3EE),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your email';
                        }

                        if (!RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(value.trim())) {
                          return 'Enter a valid email address';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: 'Enter your password',
                        labelStyle: const TextStyle(
                          color: Color(0xFFCBD5E1),
                        ),
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                        ),
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: Color(0xFF22D3EE),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: const Color(0xFF22D3EE),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        filled: true,
                        fillColor: const Color(0xFF334155),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF475569),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF22D3EE),
                            width: 2,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }

                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 10),

                    // Forgot password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Password reset is not implemented yet.',
                              ),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFF22D3EE),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF22D3EE),
                          foregroundColor: const Color(0xFF0F172A),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Sign up section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Flexible(
                          child: Text(
                            "Don't have an account?",
                            style: TextStyle(
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Registration is not implemented yet.',
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Color(0xFF22D3EE),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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
