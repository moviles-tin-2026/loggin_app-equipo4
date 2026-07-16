import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'inventory_page.dart'; // Cambiado aquí (sin la carpeta screens)// Para navegar al inventario tras el éxito


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});


  @override
  State<LoginPage> createState() => _LoginPageState();
}


class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isLogin = true;


  final Color _primaryDark = const Color(0xFF0F172A);
  final Color _accentGreen = const Color(0xFF059669);


  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;


    setState(() {
      _isLoading = true;
    });


    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );


      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inicio de sesión exitoso'),
          backgroundColor: Colors.green,
        ),
      );
     
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const InventoryPage()),
      );
     
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Error al iniciar sesión';
      if (e.code == 'user-not-found') {
        message = 'No existe un usuario con ese correo';
      } else if (e.code == 'wrong-password') {
        message = 'La contraseña es incorrecta';
      } else if (e.code == 'invalid-email') {
        message = 'El correo no es válido';
      }


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;


    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF0FDF4), Color(0xFFF8FAFC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64.0 : 24.0,
              vertical: 32.0
            ),
            child: isDesktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 5, child: _buildLeftInfoSection()),
                      const SizedBox(width: 40),
                      Expanded(flex: 4, child: _buildRightLoginCard()),
                    ],
                  )
                : Column(
                    children: [
                      _buildLeftInfoSection(),
                      const SizedBox(height: 32),
                      _buildRightLoginCard(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }


  Widget _buildLeftInfoSection() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: _primaryDark, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.hub, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text('PyME-Sync', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
            ],
          ),
          const SizedBox(height: 32),
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, height: 1.2, color: _primaryDark),
              children: [
                const TextSpan(text: 'El control absoluto de tu\n'),
                TextSpan(text: 'stock', style: TextStyle(color: _accentGreen)),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildFeatureItem(icon: Icons.sync, title: 'Módulo en construcción', description: 'No lo se desarrollo porque estabamos triste de la eliminación de México.'),
          const SizedBox(height: 16),
          _buildFeatureItem(icon: Icons.phone_iphone, title: 'Característica principal', description: 'Texto de relleno para mantener la estructura visual del diseño mientras se desarrolla.'),
          const SizedBox(height: 16),
          _buildFeatureItem(icon: Icons.cloud_done_outlined, title: 'Sistema de almacenamiento', description: 'Ian ha perdido mas de 50 apuestas.'),
          const SizedBox(height: 40),
        ],
      ),
    );
  }


  Widget _buildFeatureItem({required IconData icon, required String title, required String description}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: _accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: _accentGreen, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildRightLoginCard() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 450),
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    CircleAvatar(radius: 36, backgroundColor: _accentGreen.withOpacity(0.1), child: Icon(Icons.person, size: 40, color: _accentGreen)),
                    const SizedBox(height: 16),
                    Text('Bienvenido de nuevo', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Expanded(child: _buildTabButton('Iniciar Sesión', _isLogin, true)),
                    Expanded(child: _buildTabButton('Crear Cuenta', !_isLogin, false)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('Correo Electrónico', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(fontSize: 14),
                decoration: _inputDecoration(hint: 'Ej: correo@tuempresa.com', icon: Icons.email_outlined),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor ingresa tu correo';
                  if (!value.contains('@')) return 'Ingresa un correo válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Contraseña', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: () {},
                    child: Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _accentGreen)),
                  )
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(fontSize: 14),
                decoration: _inputDecoration(hint: 'Ingresa tu contraseña de acceso', icon: Icons.lock_outline).copyWith(
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Por favor ingresa tu contraseña';
                  if (value.length < 6) return 'Debe tener al menos 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryDark, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0),
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Ingresar a PyME-Sync', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildTabButton(String text, bool isActive, bool isLoginTab) {
    return GestureDetector(
      onTap: () => setState(() => _isLogin = isLoginTab),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        alignment: Alignment.center,
        child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.black87 : Colors.grey.shade600)),
      ),
    );
  }


  InputDecoration _inputDecoration({required String hint, required IconData icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true, fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _accentGreen)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.red)),
    );
  }
}

