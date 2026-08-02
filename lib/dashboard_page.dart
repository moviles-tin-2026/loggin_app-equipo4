import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardPage extends StatelessWidget {
  final bool isDesktop;
  final String userRole;

  const DashboardPage({super.key, required this.isDesktop, required this.userRole});

  String _formatearMoneda(double cantidad) {
    List<String> partes = cantidad.toStringAsFixed(2).split('.');
    RegExp reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    partes[0] = partes[0].replaceAll(reg, ',');
    return '\$${partes.join('.')}';
  }

  bool _esHoy(DateTime fecha) {
    DateTime hoy = DateTime.now();
    return fecha.year == hoy.year && fecha.month == hoy.month && fecha.day == hoy.day;
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryDark = const Color(0xFF0F172A);
    final Color accentGreen = const Color(0xFF10B981);
    
    final user = FirebaseAuth.instance.currentUser;
    final nombreUsuario = user?.displayName ?? (user?.email?.split('@').first ?? 'Usuario');
    
    List<String> meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    String fechaHoy = '${DateTime.now().day} de ${meses[DateTime.now().month - 1]} de ${DateTime.now().year}';

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ================= BANNER DE BIENVENIDA =================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primaryDark, const Color(0xFF1E293B)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: primaryDark.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fechaHoy.toUpperCase(), style: TextStyle(color: accentGreen, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                Text('¡Hola, $nombreUsuario!', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Aquí tienes el resumen operativo de tu negocio en tiempo real.', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ================= LAYOUT PRINCIPAL (2 COLUMNAS EN DESKTOP) =================
          Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // COLUMNA IZQUIERDA (Gráficas y Listas)
              Expanded(
                flex: isDesktop ? 7 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 3 TARJETAS KPI ---
                    Row(
                      children: [
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('ventas').snapshots(),
                            builder: (context, snapshot) {
                              double ventasHoy = 0;
                              int transaccionesHoy = 0;
                              if (snapshot.hasData) {
                                for (var doc in snapshot.data!.docs) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  if (data['fecha'] != null) {
                                    DateTime dt = (data['fecha'] as Timestamp).toDate();
                                    if (_esHoy(dt)) {
                                      ventasHoy += (data['total'] ?? 0).toDouble();
                                      transaccionesHoy++;
                                    }
                                  }
                                }
                              }
                              return _buildDashboardCard(title: 'INGRESOS DE HOY', value: _formatearMoneda(ventasHoy), subtitle: '$transaccionesHoy ventas procesadas', icon: Icons.trending_up, iconColor: accentGreen, bgColor: accentGreen.withOpacity(0.1));
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('inventarios').snapshots(),
                            builder: (context, snapshot) {
                              int alertas = 0;
                              if (snapshot.hasData) {
                                for (var doc in snapshot.data!.docs) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final int cant = data['cantidad'] ?? 0;
                                  final int min = data['stockMinimo'] ?? 0;
                                  if (cant <= min) alertas++;
                                }
                              }
                              return _buildDashboardCard(title: 'ALERTAS DE STOCK', value: alertas.toString(), subtitle: 'Productos por agotarse', icon: Icons.warning_amber_rounded, iconColor: Colors.orange, bgColor: Colors.orange.withOpacity(0.1));
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: userRole == 'administrador'
                            ? StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('usuarios').where('estado', isEqualTo: 'Activo').snapshots(),
                                builder: (context, snapshot) {
                                  int activos = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                  return _buildDashboardCard(title: 'CUENTAS ACTIVAS', value: activos.toString(), subtitle: 'Usuarios en el sistema', icon: Icons.people_alt, iconColor: Colors.blue, bgColor: Colors.blue.withOpacity(0.1));
                                },
                              )
                            : StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('inventarios').snapshots(),
                                builder: (context, snapshot) {
                                  int totalProd = snapshot.hasData ? snapshot.data!.docs.length : 0;
                                  return _buildDashboardCard(title: 'CATÁLOGO', value: totalProd.toString(), subtitle: 'Productos registrados', icon: Icons.inventory_2_outlined, iconColor: Colors.blue, bgColor: Colors.blue.withOpacity(0.1));
                                },
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // --- GRÁFICA NATIVA DE VENTAS (ÚLT 7 DÍAS) ---
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('ventas').snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
                        
                        // Preparar datos de los últimos 7 días
                        DateTime hoy = DateTime.now();
                        Map<String, double> ventasPorDia = {};
                        
                        // Inicializar los últimos 7 días en 0
                        for (int i = 6; i >= 0; i--) {
                          DateTime d = hoy.subtract(Duration(days: i));
                          String etiqueta = '${d.day}/${d.month}';
                          ventasPorDia[etiqueta] = 0.0;
                        }

                        // Llenar con datos reales
                        for (var doc in snapshot.data!.docs) {
                          final data = doc.data() as Map<String, dynamic>;
                          if (data['fecha'] != null) {
                            DateTime fechaVenta = (data['fecha'] as Timestamp).toDate();
                            // Si la venta fue en los últimos 7 días
                            if (hoy.difference(fechaVenta).inDays <= 7) {
                              String etiqueta = '${fechaVenta.day}/${fechaVenta.month}';
                              if (ventasPorDia.containsKey(etiqueta)) {
                                ventasPorDia[etiqueta] = ventasPorDia[etiqueta]! + (data['total'] ?? 0).toDouble();
                              }
                            }
                          }
                        }

                        return _buildNativeBarChart(ventasPorDia, primaryDark, accentGreen);
                      }
                    ),
                    const SizedBox(height: 24),

                    // --- ÚLTIMAS TRANSACCIONES ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Últimas 5 Transacciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDark)),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('ventas').orderBy('fecha', descending: true).limit(5).snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                              if (snapshot.data!.docs.isEmpty) return const Text('No hay ventas recientes', style: TextStyle(color: Colors.grey));
                              
                              return Column(
                                children: snapshot.data!.docs.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final folio = data['folio'] ?? 'N/A';
                                  final total = (data['total'] ?? 0).toDouble();
                                  final metodo = data['metodoPago'] ?? 'Efectivo';
                                  
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: CircleAvatar(backgroundColor: accentGreen.withOpacity(0.1), child: Icon(Icons.receipt, color: accentGreen, size: 20)),
                                    title: Text('Folio: $folio', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    subtitle: Text('Método: $metodo', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    trailing: Text(_formatearMoneda(total), style: TextStyle(fontWeight: FontWeight.bold, color: primaryDark, fontSize: 14)),
                                  );
                                }).toList(),
                              );
                            },
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
              
              if (isDesktop) const SizedBox(width: 24),
              if (!isDesktop) const SizedBox(height: 24),

              // COLUMNA DERECHA (Accesos y Estado)
              Expanded(
                flex: isDesktop ? 3 : 0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- ACCESOS RÁPIDOS ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Accesos Rápidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDark)),
                          const SizedBox(height: 16),
                          _buildBotonLateralRapido(Icons.point_of_sale, 'Ir a Punto de Venta', accentGreen, () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usa el menú lateral para abrir la caja')));
                          }),
                          const SizedBox(height: 12),
                          if (userRole != 'cajero') ...[
                            _buildBotonLateralRapido(Icons.add_box_outlined, 'Registrar Producto', primaryDark, () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ve a Inventario para registrar artículos')));
                            }),
                            const SizedBox(height: 12),
                          ],
                          if (userRole == 'administrador')
                            _buildBotonLateralRapido(Icons.security, 'Ver Log de Auditoría', Colors.purple, () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ve a Auditoría en el menú lateral')));
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // --- TOP 5 MÁS VENDIDOS (¡NUEVO!) ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.emoji_events, color: Colors.amber.shade600),
                              const SizedBox(width: 8),
                              Text('Top 5 Más Vendidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryDark)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('ventas').snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Text('Aún no hay suficientes datos.', style: TextStyle(color: Colors.grey, fontSize: 12));

                              // Diccionario para contar los productos
                              Map<String, int> conteoProductos = {};

                              for (var doc in snapshot.data!.docs) {
                                final data = doc.data() as Map<String, dynamic>;
                                final items = data['articulos'] as List<dynamic>? ?? [];
                                
                                for (var item in items) {
                                  final String nombre = item['nombre']?.toString() ?? 'Desconocido';
                                  final int cant = (item['cantidad'] ?? 0).toInt();
                                  
                                  if (conteoProductos.containsKey(nombre)) {
                                    conteoProductos[nombre] = conteoProductos[nombre]! + cant;
                                  } else {
                                    conteoProductos[nombre] = cant;
                                  }
                                }
                              }

                              if (conteoProductos.isEmpty) return const Text('Sin datos calculables', style: TextStyle(color: Colors.grey, fontSize: 12));

                              // Ordenar de mayor a menor y tomar los primeros 5
                              var listaOrdenada = conteoProductos.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
                              var top5 = listaOrdenada.take(5).toList();

                              return Column(
                                children: List.generate(top5.length, (index) {
                                  final item = top5[index];
                                  final isFirst = index == 0;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28, height: 28,
                                          decoration: BoxDecoration(
                                            color: isFirst ? Colors.amber.shade100 : Colors.grey.shade100,
                                            shape: BoxShape.circle
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${index + 1}', 
                                              style: TextStyle(fontWeight: FontWeight.bold, color: isFirst ? Colors.amber.shade800 : Colors.grey.shade600, fontSize: 12)
                                            )
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(item.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                        ),
                                        Text('${item.value} uds', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: accentGreen)),
                                      ],
                                    ),
                                  );
                                }),
                              );
                            }
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- MINI PANEL INFORMATIVO (Dato Curioso/Ayuda) ---
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.blue.shade100)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [Icon(Icons.lightbulb_outline, color: Colors.blue.shade700), const SizedBox(width: 8), Text('Tip del Sistema', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade900))]),
                          const SizedBox(height: 12),
                          Text('Recuerda revisar diariamente la tarjeta de "Alertas de Stock". Mantener tu inventario sano asegura que nunca pierdas una venta por falta de mercancía.', style: TextStyle(fontSize: 12, color: Colors.blue.shade800, height: 1.5)),
                        ],
                      ),
                    )
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }

  // ==================== COMPONENTES VISUALES ====================

  Widget _buildDashboardCard({required String title, required String value, required String subtitle, required IconData icon, required Color iconColor, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 20)),
              const Spacer(),
              Icon(Icons.more_horiz, color: Colors.grey.shade400)
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildBotonLateralRapido(IconData icon, String texto, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 12),
            Text(texto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400)
          ],
        ),
      ),
    );
  }

  // --- GRÁFICA DE BARRAS NATIVA Y RESPONSIVA ---
  Widget _buildNativeBarChart(Map<String, double> datos, Color primary, Color accent) {
    // Buscar el valor máximo para calcular proporciones
    double maxValor = 0;
    for (var val in datos.values) {
      if (val > maxValor) maxValor = val;
    }
    if (maxValor == 0) maxValor = 1; // Evitar división por cero

    return Container(
      height: 250,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ingresos de los últimos 7 días', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primary)),
              Icon(Icons.bar_chart, color: Colors.grey.shade400)
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: datos.entries.map((entry) {
                double heightPct = entry.value / maxValor;
                return Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // El Tooltip permite ver la cifra exacta al poner el mouse encima
                    Tooltip(
                      message: 'Ventas: ${_formatearMoneda(entry.value)}',
                      preferBelow: false,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 800),
                        curve: Curves.easeOut,
                        width: 28,
                        height: 120 * heightPct, // Altura dinámica
                        decoration: BoxDecoration(
                          color: entry.value > 0 ? accent : Colors.grey.shade200,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6))
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(entry.key, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}