import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'inventory_page.dart';

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

  // NUEVA PALETA DE COLORES DARK MODE
  final Color _bgDark = const Color(0xFF09090B); // Fondo principal
  final Color _cardDark = const Color(0xFF131316); // Tarjeta del login
  final Color _inputDark = const Color(0xFF1C1C21); // Cajas de texto
  final Color _accentGreen = const Color(0xFF10B981); // Verde brillante
  final Color _textWhite = const Color(0xFFF8FAFC); // Texto principal
  final Color _textGray = const Color(0xFF94A3B8); // Texto secundario

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // =======================================================
  // TU LÓGICA DE FIREBASE INTACTA
  // =======================================================
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Iniciar sesión con Firebase Auth
      UserCredential userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      // 2. Buscar el perfil del usuario en Firestore para ver su Rol y Estado
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userCredential.user!.uid)
          .get();

      if (!mounted) return;

      if (userDoc.exists) {
        // Extraer los datos (Si no tiene, asume activo y cajero por seguridad)
        String estado = userDoc.get('estado') ?? 'Activo';
        String rol = userDoc.get('rol') ?? 'cajero';

        // 3. Validar si la cuenta fue inhabilitada por un Administrador
        if (estado == 'Inactivo') {
          await FirebaseAuth.instance
              .signOut(); // Le cerramos la sesión inmediatamente
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tu cuenta está inhabilitada. Contacta al administrador.',
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {
            _isLoading = false;
          });
          return; // Detenemos el proceso para que no entre
        }

        // 4. Si la cuenta está activa, mostramos mensaje personalizado y lo dejamos entrar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Inicio exitoso. Estás en modo: ${rol.toUpperCase()}',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const InventoryPage()),
        );
      } else {
        // Si por alguna razón el usuario está en Auth pero no en Firestore
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Error: No se encontró el perfil del usuario en la base de datos.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String message = 'Error al iniciar sesión';
      if (e.code == 'user-not-found') {
        message = 'No existe un usuario con ese correo';
      } else if (e.code == 'wrong-password') {
        message = 'La contraseña es incorrecta';
      } else if (e.code == 'invalid-email') {
        message = 'El correo no es válido';
      } else if (e.code == 'user-disabled') {
        message = 'Esta cuenta ha sido deshabilitada desde Firebase.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error inesperado: $e'),
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

  // =======================================================
  // DISEÑO VISUAL (NUEVO DARK MODE)
  // =======================================================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: _bgDark,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          // Simulamos el resplandor verde de la imagen en el fondo
          gradient: RadialGradient(
            center: const Alignment(-0.8, 0.0),
            radius: 1.2,
            colors: [
              const Color(0xFF062D20).withOpacity(0.8), // Verde oscuro
              _bgDark, // Negro
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 64.0 : 24.0,
              vertical: 32.0,
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
                decoration: BoxDecoration(
                  color: _textWhite,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: _accentGreen.withOpacity(0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Icon(Icons.hub, color: _bgDark, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'PyME-Sync',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _textWhite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                height: 1.2,
                color: _textWhite,
              ),
              children: [
                const TextSpan(text: 'El control\nabsoluto de tu\n'),
                TextSpan(
                  text: 'stock',
                  style: TextStyle(color: _accentGreen),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Una plataforma inteligente para gestionar, sincronizar y controlar tu inventario en tiempo real.',
            style: TextStyle(fontSize: 14, color: _textGray, height: 1.5),
          ),
          const SizedBox(height: 48),
          _buildFeatureItem(
            icon: Icons.sync,
            title: 'Escalable',
            description:
                'Sistema con la capacidad de crecer y manejar procesos de manera eficiente.',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.phone_iphone,
            title: 'Responsivo',
            description:
                'App movil adaptable a diferentes pantallas de distintos dispositivos',
          ),
          const SizedBox(height: 16),
          _buildFeatureItem(
            icon: Icons.cloud_done_outlined,
            title: 'Firebase',
            description: 'Almacenamiento en la nube.',
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            border: Border.all(color: _accentGreen.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: _accentGreen, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: _textWhite,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(fontSize: 12, color: _textGray),
              ),
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
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: _cardDark,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    // El avatar con resplandor verde
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _accentGreen.withOpacity(0.1),
                        boxShadow: [
                          BoxShadow(
                            color: _accentGreen.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(Icons.person, size: 36, color: _accentGreen),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Bienvenido de nuevo',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: _textWhite,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ingresa tus credenciales para continuar',
                      style: TextStyle(fontSize: 13, color: _textGray),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              Text(
                'Correo Electrónico',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _textWhite,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(fontSize: 14, color: _textWhite),
                decoration: _inputDecoration(
                  hint: 'ej: correo@tuempresa.com',
                  icon: Icons.email_outlined,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Por favor ingresa tu correo';
                  if (!value.contains('@')) return 'Ingresa un correo válido';
                  return null;
                },
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contraseña',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _textWhite,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _accentGreen,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: TextStyle(fontSize: 14, color: _textWhite),
                decoration:
                    _inputDecoration(
                      hint: 'Ingresa tu contraseña de acceso',
                      icon: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: _textGray,
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                validator: (value) {
                  if (value == null || value.isEmpty)
                    return 'Por favor ingresa tu contraseña';
                  if (value.length < 6)
                    return 'Debe tener al menos 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accentGreen,
                    foregroundColor: _bgDark, // Texto oscuro sobre botón verde
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _bgDark,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              'Ingresar a PyME-Sync',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: _textGray.withOpacity(0.5)),
      prefixIcon: Icon(icon, color: _textGray, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      filled: true,
      fillColor: _inputDark,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.transparent),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _accentGreen.withOpacity(0.5)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red.withOpacity(0.5)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }
}
