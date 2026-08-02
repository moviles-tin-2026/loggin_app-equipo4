import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogsPage extends StatefulWidget {
  final bool isDesktop;
  const LogsPage({super.key, required this.isDesktop});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final Color _primaryDark = const Color(0xFF0F172A);

  // Memoria caché para no leer Firebase a cada rato
  final Map<String, String> _rolesCache = {};

  // Función inteligente para obtener el rol y su color
  Future<String> _obtenerRol(String email, String accion, String modulo) async {
    if (email == 'Sistema') return 'sistema';
    if (_rolesCache.containsKey(email)) return _rolesCache[email]!;

    try {
      // 1. Intenta buscar el rol en la base de datos por el correo
      final query = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        String rol =
            query.docs.first.data()['rol']?.toString().toLowerCase() ?? '';
        if (rol.isNotEmpty) {
          _rolesCache[email] = rol;
          return rol;
        }
      }
    } catch (e) {
      debugPrint("Error buscando rol: $e");
    }

    // 2. Si falla (porque Firebase no tiene el email guardado), usa Inteligencia para deducirlo
    String rolInferido = 'usuario general';
    String accL = accion.toLowerCase();

    if (accL.contains('cajero'))
      rolInferido = 'cajero';
    else if (accL.contains('supervisor'))
      rolInferido = 'supervisor';
    else if (accL.contains('administrador') || accL.contains('admin'))
      rolInferido = 'administrador';
    else if (modulo == 'Ventas')
      rolInferido = 'cajero'; // Las ventas son de cajeros
    else if (modulo == 'Usuarios' || modulo == 'Acceso')
      rolInferido = 'administrador'; // Accesos son de admin
    else if (modulo == 'Inventario' && accL.contains('solicitó stock'))
      rolInferido = 'supervisor';
    else if (modulo == 'Inventario' && accL.contains('confirmó recepción'))
      rolInferido = 'administrador';
    else if (modulo == 'Inventario')
      rolInferido = 'supervisor'; // Por defecto en inventario

    _rolesCache[email] = rolInferido;
    return rolInferido;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(widget.isDesktop ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log de Accesos y Cambios',
            style: TextStyle(
              fontSize: widget.isDesktop ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: _primaryDark,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Historial inmutable de auditoría y movimientos críticos del sistema.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('logs')
                    .orderBy('fecha', descending: true)
                    .limit(100)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.security_rounded,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No hay registros de actividad aún.',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: snapshot.data!.docs.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final data =
                          snapshot.data!.docs[index].data()
                              as Map<String, dynamic>;

                      final String modulo = data['modulo'] ?? 'Sistema';
                      final String accion =
                          data['accion'] ?? 'Acción desconocida';
                      final String usuario = data['usuario'] ?? 'Desconocido';

                      String fechaStr = 'Calculando...';
                      if (data['fecha'] != null) {
                        DateTime dt = (data['fecha'] as Timestamp).toDate();
                        String min = dt.minute.toString().padLeft(2, '0');
                        fechaStr =
                            '${dt.day}/${dt.month}/${dt.year} a las ${dt.hour}:$min';
                      }

                      IconData iconoModulo = Icons.info_outline;
                      if (modulo == 'Usuarios') iconoModulo = Icons.people;
                      if (modulo == 'Inventario')
                        iconoModulo = Icons.inventory_2;
                      if (modulo == 'Ventas') iconoModulo = Icons.point_of_sale;
                      if (modulo == 'Acceso') iconoModulo = Icons.login;

                      return FutureBuilder<String>(
                        future: _obtenerRol(usuario, accion, modulo),
                        builder: (context, rolSnapshot) {
                          String rol = rolSnapshot.data ?? 'cargando...';

                          // ASIGNACIÓN DE COLORES POR ROL
                          Color colorRol = Colors.grey.shade600;
                          Color bgRol = Colors.grey.shade100;

                          if (rol == 'administrador' || rol == 'admin') {
                            colorRol = Colors.purple.shade700;
                            bgRol = Colors.purple.shade50;
                          } else if (rol == 'supervisor') {
                            colorRol = Colors.blue.shade700;
                            bgRol = Colors.blue.shade50;
                          } else if (rol == 'cajero') {
                            colorRol = Colors.orange.shade800;
                            bgRol = Colors.orange.shade50;
                          } else if (rol == 'sistema') {
                            colorRol = _primaryDark;
                            bgRol = Colors.grey.shade200;
                          }

                          // NUEVO DISEÑO: Más amplio, sin cortar textos y con el color del rol dominando
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icono coloreado con el color del Rol
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: colorRol.withOpacity(0.15),
                                  child: Icon(
                                    iconoModulo,
                                    color: colorRol,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Fila Superior: Etiqueta de Rol y Fecha
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: bgRol,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: colorRol.withOpacity(
                                                  0.3,
                                                ),
                                              ),
                                            ),
                                            child: Text(
                                              rol.toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: colorRol,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            fechaStr,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      // Fila Central: La acción completa (¡Ya no se corta!)
                                      Text(
                                        accion,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: _primaryDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Fila Inferior: Autor y Módulo
                                      Text(
                                        'Autor: $usuario   •   Módulo: $modulo',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
