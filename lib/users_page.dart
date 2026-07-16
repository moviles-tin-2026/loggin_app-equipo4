import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UsersPage extends StatefulWidget {
  final bool isDesktop;
  const UsersPage({super.key, required this.isDesktop});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controladores del formulario
  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _searchController = TextEditingController();

  String _busquedaQuery = '';

  final Color _primaryDark = const Color(0xFF0F172A);
  final Color _accentGreen = const Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _busquedaQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _correoController.dispose();
    _passwordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // =======================================================
  // LÓGICA DE FIREBASE (AUTH + FIRESTORE)
  // =======================================================
  Future<void> _registrarUsuario() async {
    final nombre = _nombreController.text.trim();
    final correo = _correoController.text.trim();
    final password = _passwordController.text.trim();

    if (nombre.isEmpty || correo.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contraseña debe tener al menos 6 caracteres'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // 1. Crear el usuario en Firebase Authentication (La bóveda segura)
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: correo, password: password);

      // 2. Guardar el "espejo" en Firestore para poder verlo en la tabla
      await _firestore
          .collection('usuarios')
          .doc(userCredential.user!.uid)
          .set({
            'nombre': nombre,
            'correo': correo,
            'estado': 'Activo',
            'fechaRegistro': FieldValue.serverTimestamp(),
            'idUsuario': userCredential.user!.uid,
          });

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario registrado y sincronizado exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } on FirebaseAuthException catch (e) {
      String mensaje = 'Error al registrar';
      if (e.code == 'email-already-in-use')
        mensaje = 'Este correo ya está registrado en Firebase.';
      if (e.code == 'invalid-email')
        mensaje = 'El formato del correo es inválido.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _cambiarEstado(
    String docId,
    String nombre,
    String estadoActual,
  ) async {
    final String nuevoEstado = estadoActual == 'Activo' ? 'Inactivo' : 'Activo';

    try {
      await _firestore.collection('usuarios').doc(docId).update({
        'estado': nuevoEstado,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blueAccent),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'El estado de "$nombre" ahora es $nuevoEstado.',
                  style: const TextStyle(color: Colors.black87),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          elevation: 4,
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).size.height - 100,
            right: 20,
            left: widget.isDesktop
                ? MediaQuery.of(context).size.width - 400
                : 20,
          ),
          action: SnackBarAction(
            label: '✕',
            textColor: Colors.grey,
            onPressed: () {},
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al actualizar estado'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarUsuario(String docId, String nombre) async {
    try {
      await _firestore.collection('usuarios').doc(docId).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Usuario $nombre eliminado del panel'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al eliminar'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarFormularioRegistro() {
    _nombreController.clear();
    _correoController.clear();
    _passwordController.clear();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _primaryDark.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.person_add_alt_1, color: _primaryDark),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      'Registrar Usuario',
                      style: TextStyle(
                        color: _primaryDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nombreController,
                  decoration: InputDecoration(
                    labelText: 'Nombre Completo',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _correoController,
                  decoration: InputDecoration(
                    labelText: 'Correo Electrónico',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña de Acceso',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryDark,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _registrarUsuario,
                      child: const Text('Crear Usuario'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =======================================================
  // DISEÑO DE LA PANTALLA PRINCIPAL
  // =======================================================
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget.isDesktop ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administración de Usuarios',
                      style: TextStyle(
                        fontSize: widget.isDesktop ? 24 : 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Visualiza y gestiona las cuentas con acceso al sistema.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (widget.isDesktop)
                ElevatedButton.icon(
                  onPressed: _mostrarFormularioRegistro,
                  icon: const Icon(Icons.person_add, size: 16),
                  label: const Text('Agregar Usuario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          if (!widget.isDesktop) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _mostrarFormularioRegistro,
                icon: const Icon(Icons.person_add, size: 14),
                label: const Text(
                  'Agregar Usuario',
                  style: TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryDark,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Buscador sin filtro de roles
          Container(
            padding: EdgeInsets.all(widget.isDesktop ? 0 : 16),
            decoration: widget.isDesktop
                ? null
                : BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o correo electrónico...',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: Colors.grey,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('usuarios')
                  .orderBy('fechaRegistro', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(
                    child: Text(
                      'No hay usuarios registrados en la base de datos',
                    ),
                  );

                var docs = snapshot.data!.docs;

                docs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre = (data['nombre'] ?? '')
                      .toString()
                      .toLowerCase();
                  final correo = (data['correo'] ?? '')
                      .toString()
                      .toLowerCase();
                  return nombre.contains(_busquedaQuery) ||
                      correo.contains(_busquedaQuery);
                }).toList();

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final double cardWidth = widget.isDesktop
                        ? (constraints.maxWidth - 24) / 2
                        : constraints.maxWidth;

                    return SingleChildScrollView(
                      child: Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: docs.map((doc) {
                          return SizedBox(
                            width: cardWidth,
                            child: _buildUserCard(
                              doc.id,
                              doc.data() as Map<String, dynamic>,
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // =======================================================
  // TARJETA DE USUARIO SIMPLIFICADA
  // =======================================================
  Widget _buildUserCard(String docId, Map<String, dynamic> data) {
    final nombre = data['nombre'] ?? 'Sin Nombre';
    final correo = data['correo'] ?? 'sin@correo.com';
    final idUsuario = data['idUsuario'] ?? docId;
    final estado = data['estado'] ?? 'Activo';

    String fechaTexto = 'Sin fecha';
    if (data['fechaRegistro'] != null) {
      DateTime dt = (data['fechaRegistro'] as Timestamp).toDate();
      List<String> meses = [
        'enero',
        'febrero',
        'marzo',
        'abril',
        'mayo',
        'junio',
        'julio',
        'agosto',
        'septiembre',
        'octubre',
        'noviembre',
        'diciembre',
      ];
      fechaTexto = '${dt.day} de ${meses[dt.month - 1]} de ${dt.year}';
    }

    String iniciales = 'US';
    if (nombre.trim().isNotEmpty) {
      List<String> partes = nombre.trim().split(' ');
      if (partes.length > 1) {
        iniciales = '${partes[0][0]}${partes[1][0]}'.toUpperCase();
      } else {
        iniciales = nombre
            .substring(0, nombre.length > 1 ? 2 : 1)
            .toUpperCase();
      }
    }

    bool isActive = estado == 'Activo';
    Color estadoBg = isActive
        ? _accentGreen.withOpacity(0.1)
        : Colors.red.withOpacity(0.1);
    Color estadoText = isActive ? _accentGreen : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.blueAccent,
                child: Text(
                  iniciales,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 12,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            correo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Agregado el $fechaTexto',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
              InkWell(
                onTap: () => _cambiarEstado(docId, nombre, estado),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: estadoBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: estadoText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.perm_identity,
                    size: 14,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'UID: ${idUsuario.toString().substring(0, 8)}...',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Eliminar Usuario?'),
                      content: Text(
                        'Estás a punto de eliminar a $nombre del panel.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _eliminarUsuario(docId, nombre);
                          },
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  );
                },
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: Colors.grey.shade400,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
