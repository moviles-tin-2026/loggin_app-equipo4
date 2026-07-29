import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LogsPage extends StatelessWidget {
  final bool isDesktop;
  const LogsPage({super.key, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final Color _primaryDark = const Color(0xFF0F172A);

    return Padding(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log de Accesos y Cambios',
            style: TextStyle(
              fontSize: isDesktop ? 24 : 20,
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
                // Leemos la colección 'logs' y la ordenamos de lo más reciente a lo más viejo
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

                      // Asignar icono y color según el módulo para que se vea más pro
                      IconData icono = Icons.info_outline;
                      Color colorIcono = Colors.blueGrey;

                      if (modulo == 'Usuarios') {
                        icono = Icons.people;
                        colorIcono = Colors.purple;
                      }
                      if (modulo == 'Inventario') {
                        icono = Icons.inventory_2;
                        colorIcono = Colors.orange;
                      }
                      if (modulo == 'Ventas') {
                        icono = Icons.point_of_sale;
                        colorIcono = Colors.green;
                      }
                      if (modulo == 'Acceso') {
                        icono = Icons.login;
                        colorIcono = Colors.blue;
                      }

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: colorIcono.withOpacity(0.1),
                          child: Icon(icono, color: colorIcono, size: 20),
                        ),
                        title: Text(
                          accion,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(
                            top: 4.0,
                          ), // <--- ¡AQUÍ ESTABA EL ERROR CORREGIDO!
                          child: Text(
                            'Autor: $usuario   •   Módulo: $modulo',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        trailing: Text(
                          fechaStr,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
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
