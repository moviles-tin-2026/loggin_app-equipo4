import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class SalesPage extends StatefulWidget {
  final bool isDesktop;
  const SalesPage({super.key, required this.isDesktop});


  @override
  State<SalesPage> createState() => _SalesPageState();
}


class _SalesPageState extends State<SalesPage> {
  // VARIABLES MÓDULO DE VENTAS (POS)
  bool _isRegistrarVenta = true;
  List<Map<String, dynamic>> _carrito = [];
  String _metodoPago = 'Efectivo';
  final _searchVentasController = TextEditingController();
  String _busquedaVentasQuery = '';
  String _filtroCategoriaVentas = 'Todos';
  String _filtroHistorialPagos = 'Todos los Métodos';
  final List<String> _categorias = [
    'Computadoras y laptops',
    'Componentes',
    'Periféricos',
    'Audio',
    'Accesorios'
  ];


  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  // PALETA DE COLORES (BRANDING)
  final Color _primaryDark = const Color(0xFF0F172A);
  final Color _accentGreen = const Color(0xFF10B981);


  @override
  void initState() {
    super.initState();
    _searchVentasController.addListener(() {
      setState(() => _busquedaVentasQuery = _searchVentasController.text.toLowerCase());
    });
  }


  @override
  void dispose() {
    _searchVentasController.dispose();
    super.dispose();
  }


  // =======================================================
  // FORMATEADORES NATIVOS
  // =======================================================
  String _formatearMoneda(double cantidad) {
    List<String> partes = cantidad.toStringAsFixed(2).split('.');
    RegExp reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    partes[0] = partes[0].replaceAll(reg, ',');
    return '\$${partes.join('.')}';
  }


  String _formatearFechaNativa(DateTime date) {
    String dia = date.day.toString().padLeft(2, '0');
    String mes = date.month.toString().padLeft(2, '0');
    String anio = date.year.toString();
   
    int hour = date.hour;
    String periodo = hour >= 12 ? 'p.m.' : 'a.m.';
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;
   
    String hora = hour.toString().padLeft(2, '0');
    String minuto = date.minute.toString().padLeft(2, '0');
   
    return '$dia/$mes/$anio - $hora:$minuto $periodo';
  }


  // =======================================================
  // LÓGICA DE CONTROL DEL CARRITO
  // =======================================================
  void _agregarAlCarrito(String docId, Map<String, dynamic> data) {
    final int stockDisponible = data['cantidad'] ?? 0;
    if (stockDisponible <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Producto sin stock disponible'), backgroundColor: Colors.red)
      );
      return;
    }


    setState(() {
      final int index = _carrito.indexWhere((item) => item['docId'] == docId);
      if (index >= 0) {
        if (_carrito[index]['cantidadCarrito'] < stockDisponible) {
          _carrito[index]['cantidadCarrito']++;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock máximo alcanzado para este producto'))
          );
        }
      } else {
        _carrito.add({
          'docId': docId,
          'nombre': data['nombre'],
          'precio': (data['precio'] ?? 0).toDouble(),
          'cantidadCarrito': 1,
          'stockDisponible': stockDisponible
        });
      }
    });
  }


  void _ajustarCantidadCarrito(int index, int ajuste) {
    setState(() {
      final nuevaCantidad = _carrito[index]['cantidadCarrito'] + ajuste;
      if (nuevaCantidad <= 0) {
        _carrito.removeAt(index);
      } else if (nuevaCantidad <= _carrito[index]['stockDisponible']) {
        _carrito[index]['cantidadCarrito'] = nuevaCantidad;
      }
    });
  }


  double get _subtotalCarrito => _carrito.fold(0, (sum, item) => sum + (item['precio'] * item['cantidadCarrito']));
  double get _ivaCarrito => _subtotalCarrito * 0.16;
  double get _totalCarrito => _subtotalCarrito + _ivaCarrito;


  // =======================================================
  // PROCESAMIENTO DE TRANSACCIONES (BATCH)
  // =======================================================
  Future<void> _procesarVenta() async {
    if (_carrito.isEmpty) return;


    final String folio = 'SALE-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
   
    List<Map<String, dynamic>> itemsVenta = _carrito.map((item) => {
      'docId': item['docId'],
      'nombre': item['nombre'],
      'precio': item['precio'],
      'cantidad': item['cantidadCarrito'],
    }).toList();


    try {
      WriteBatch batch = _firestore.batch();
      DocumentReference ventaRef = _firestore.collection('ventas').doc();
     
      batch.set(ventaRef, {
        'folio': folio,
        'fecha': FieldValue.serverTimestamp(),
        'cliente': 'Mostrador General',
        'metodoPago': _metodoPago,
        'subtotal': _subtotalCarrito,
        'iva': _ivaCarrito,
        'total': _totalCarrito,
        'articulos': itemsVenta,
        'usuarioId': FirebaseAuth.instance.currentUser?.uid,
      });


      for (var item in _carrito) {
        DocumentReference invRef = _firestore.collection('inventarios').doc(item['docId']);
        batch.update(invRef, {
          'cantidad': FieldValue.increment(-item['cantidadCarrito'])
        });
      }


      await batch.commit();


      if (!mounted) return;
      _mostrarTicketExito(folio, itemsVenta, _subtotalCarrito, _ivaCarrito, _totalCarrito, _metodoPago);
     
      setState(() {
        _carrito.clear();
      });


    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al procesar venta: $e'), backgroundColor: Colors.red)
      );
    }
  }


  void _mostrarTicketExito(String folio, List<Map<String, dynamic>> items, double sub, double iva, double total, String metodo) {
    DateTime ahora = DateTime.now();
    String fechaActual = "${ahora.day}/${ahora.month}/${ahora.year}";
    String horaActual = "${ahora.hour.toString().padLeft(2, '0')}:${ahora.minute.toString().padLeft(2, '0')}";


    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: _accentGreen.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.check_circle_outline, color: _accentGreen, size: 48)
              ),
              const SizedBox(height: 16),
              Text('¡Venta Exitosa!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _primaryDark)),
              const SizedBox(height: 8),
              const Text('Ticket generado correctamente', style: TextStyle(color: Colors.grey)),
              const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider()),
             
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('FOLIO: $folio', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 4), Text('FECHA: $fechaActual', style: const TextStyle(fontSize: 10, color: Colors.grey))]),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(horaActual, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 4), const Text('CAJA: #1', style: TextStyle(fontSize: 10, color: Colors.grey))]),
                ],
              ),
              const SizedBox(height: 24),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [Text('CONCEPTO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)), Text('IMPORTE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))]),
              const SizedBox(height: 8),
              ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${item['cantidad']}x ${item['nombre']}', style: const TextStyle(fontSize: 13))),
                    Text(_formatearMoneda(item['precio'] * item['cantidad']), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                ),
              )).toList(),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal', style: TextStyle(fontSize: 12)), Text(_formatearMoneda(sub), style: const TextStyle(fontSize: 12))]),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('IVA (16%)', style: TextStyle(fontSize: 12)), Text(_formatearMoneda(iva), style: const TextStyle(fontSize: 12))]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total Pagado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDark)), Text(_formatearMoneda(total), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark))]),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('MÉTODO DE PAGO', style: TextStyle(fontSize: 10, color: Colors.grey)), Text(metodo.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _primaryDark))]),
              const SizedBox(height: 32),
             
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () {}, style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: BorderSide(color: _primaryDark), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: Text('Imprimir', style: TextStyle(color: _primaryDark)))),
                  const SizedBox(width: 16),
                  Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: _primaryDark, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Aceptar'))),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }


  // =======================================================
  // DISEÑO PRINCIPAL (BUILD)
  // =======================================================
  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
   
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTabVentas('Registrar Venta', Icons.point_of_sale_outlined, _isRegistrarVenta, () => setState(() => _isRegistrarVenta = true)),
                  _buildTabVentas('Historial de Ventas', Icons.history, !_isRegistrarVenta, () => setState(() => _isRegistrarVenta = false)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _isRegistrarVenta ? _buildPuntoDeVenta(isDesktop) : _buildHistorialVentas(isDesktop),
          ),
        ],
      ),
    );
  }


  Widget _buildTabVentas(String title, IconData icon, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: isActive ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? _primaryDark : Colors.grey.shade500),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isActive ? _primaryDark : Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }


  // =======================================================
  // SECCIÓN: REGISTRAR VENTA (RESPONSIVO REAL)
  // =======================================================
  Widget _buildPuntoDeVenta(bool isDesktop) {
    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: _buildCatalogoPOS(isDesktop)),
          const SizedBox(width: 24),
          Expanded(flex: 3, child: _buildCarritoPOS(isDesktop)),
        ],
      );
    } else {
      // MEJORA EN MÓVIL: Una sola tira vertical scrollable sin pantallas divididas
      return SingleChildScrollView(
        child: Column(
          children: [
            _buildCatalogoPOS(isDesktop),
            const SizedBox(height: 24),
            _buildCarritoPOS(isDesktop),
          ],
        ),
      );
    }
  }


  Widget _buildCatalogoPOS(bool isDesktop) {
    Widget gridContenido = StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('inventarios').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('No hay productos disponibles'));


        var docs = snapshot.data!.docs;
       
        docs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final nombre = (data['nombre'] ?? '').toString().toLowerCase();
          final cat = data['categoria'] ?? '';
         
          bool matchCategoria = _filtroCategoriaVentas == 'Todos' || cat == _filtroCategoriaVentas;
          bool matchBusqueda = nombre.contains(_busquedaVentasQuery);
          return matchCategoria && matchBusqueda;
        }).toList();


        return GridView.builder(
          shrinkWrap: !isDesktop, // Clave para evitar desbordamiento en scroll nativo móvil
          physics: isDesktop ? null : const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 3 : 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final docId = docs[index].id;
           
            final nombre = data['nombre'] ?? '';
            final cat = data['categoria'] ?? '';
            final precio = (data['precio'] ?? 0).toDouble();
            final stock = data['cantidad'] ?? 0;
            final stockMin = data['stockMinimo'] ?? 0;
            final urlImg = data['urlImagen'] ?? '';
           
            return InkWell(
              onTap: () => _agregarAlCarrito(docId, data),
              child: Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
                            child: urlImg.isNotEmpty
                              ? ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(urlImg, fit: BoxFit.cover))
                              : const Icon(Icons.inventory_2, size: 40, color: Colors.grey),
                          ),
                          if (stock <= stockMin)
                            Positioned(top: 8, left: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(4)), child: const Text('BAJO STOCK', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)))),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cat.toUpperCase(), style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(nombre, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryDark), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatearMoneda(precio), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryDark)),
                              Text('Stock: $stock', style: TextStyle(fontSize: 10, color: stock <= stockMin ? Colors.orange : Colors.grey)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );


    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Column(
            children: [
              TextField(
                controller: _searchVentasController,
                decoration: InputDecoration(hintText: 'Buscar productos por nombre o categoría...', prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPillVentas('Todos'),
                    ..._categorias.map((c) => _buildPillVentas(c)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        isDesktop ? Expanded(child: gridContenido) : gridContenido,
      ],
    );
  }


  Widget _buildPillVentas(String label) {
    final bool isActive = _filtroCategoriaVentas == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label), selected: isActive,
        onSelected: (val) { if (val) setState(() => _filtroCategoriaVentas = label); },
        labelStyle: TextStyle(color: isActive ? Colors.white : Colors.grey.shade700, fontSize: 12),
        selectedColor: _primaryDark, backgroundColor: Colors.white,
        side: BorderSide(color: isActive ? _primaryDark : Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }


  Widget _buildCarritoPOS(bool isDesktop) {
    Widget carritoCuerpo = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(Icons.receipt_long, color: _primaryDark, size: 18), const SizedBox(width: 8), Text('Registro de Venta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark))]),
              if (_carrito.isNotEmpty)
                IconButton(icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey), onPressed: () => setState(() => _carrito.clear()), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ],
          ),
        ),
        Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: Colors.grey.shade50, child: const Text('Cliente: Mostrador General', style: TextStyle(fontSize: 11, color: Colors.grey))),
       
        _carrito.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 48.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.shopping_basket_outlined, size: 48, color: Color(0xFFCBD5E1)),
                    SizedBox(height: 12),
                    Text('Venta sin productos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _carrito.length,
              separatorBuilder: (c, i) => const Divider(),
              itemBuilder: (context, index) {
                final item = _carrito[index];
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['nombre'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          Text(_formatearMoneda(item['precio']), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        InkWell(onTap: () => _ajustarCantidadCarrito(index, -1), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.remove, size: 14))),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('${item['cantidadCarrito']}', style: const TextStyle(fontWeight: FontWeight.bold))),
                        InkWell(onTap: () => _ajustarCantidadCarrito(index, 1), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.add, size: 14))),
                      ],
                    )
                  ],
                );
              },
            ),
       
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(bottom: Radius.circular(16))),
          child: Column(
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal', style: TextStyle(fontSize: 12)), Text(_formatearMoneda(_subtotalCarrito), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('IVA (16%)', style: TextStyle(fontSize: 12)), Text(_formatearMoneda(_ivaCarrito), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider()),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryDark)), Text(_formatearMoneda(_totalCarrito), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark))]),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('MÉTODO DE PAGO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _metodoPago = 'Efectivo'),
                      child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _metodoPago == 'Efectivo' ? _accentGreen.withOpacity(0.1) : Colors.white, border: Border.all(color: _metodoPago == 'Efectivo' ? _accentGreen : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.money, size: 14, color: _metodoPago == 'Efectivo' ? _accentGreen : Colors.grey), const SizedBox(width: 6), Text('Efectivo', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _metodoPago == 'Efectivo' ? _accentGreen : Colors.grey))])),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _metodoPago = 'Tarjeta'),
                      child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: _metodoPago == 'Tarjeta' ? Colors.blue.shade50 : Colors.white, border: Border.all(color: _metodoPago == 'Tarjeta' ? Colors.blue : Colors.grey.shade300), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.credit_card, size: 14, color: _metodoPago == 'Tarjeta' ? Colors.blue : Colors.grey), const SizedBox(width: 6), Text('Tarjeta', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _metodoPago == 'Tarjeta' ? Colors.blue : Colors.grey))])),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _carrito.isEmpty ? null : _procesarVenta,
                  style: ElevatedButton.styleFrom(backgroundColor: _primaryDark, disabledBackgroundColor: Colors.grey.shade300, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Finalizar Venta', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        )
      ],
    );


    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: isDesktop ? SingleChildScrollView(child: carritoCuerpo) : carritoCuerpo,
    );
  }


  // =======================================================
  // SECCIÓN: HISTORIAL DE VENTAS (RESPONSIVO COMPLETO)
  // =======================================================
  Widget _buildHistorialVentas(bool isDesktop) {
    Widget contenidoHistorial = Column(
      children: [
        // Indicadores (KPIs) superiores
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('ventas').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox();
            double totalVendido = 0;
            int totalTransacciones = snapshot.data!.docs.length;
           
            for(var doc in snapshot.data!.docs) {
              totalVendido += (doc['total'] ?? 0).toDouble();
            }
            double ticketPromedio = totalTransacciones > 0 ? totalVendido / totalTransacciones : 0;


            return Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              children: [
                Expanded(flex: isDesktop ? 1 : 0, child: Container(margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16), child: _buildKPICard(icon: Icons.trending_up, iconColor: Colors.blue, bgColor: Colors.blue.withOpacity(0.1), title: 'TOTAL VENDIDO', value: _formatearMoneda(totalVendido)))),
                if(isDesktop) const SizedBox(width: 16),
                Expanded(flex: isDesktop ? 1 : 0, child: Container(margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16), child: _buildKPICard(icon: Icons.receipt_long, iconColor: _accentGreen, bgColor: _accentGreen.withOpacity(0.1), title: 'TRANSACCIONES', value: '$totalTransacciones ventas'))),
                if(isDesktop) const SizedBox(width: 16),
                Expanded(flex: isDesktop ? 1 : 0, child: Container(margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16), child: _buildKPICard(icon: Icons.local_activity, iconColor: Colors.orange, bgColor: Colors.orange.withOpacity(0.1), title: 'TICKET PROMEDIO', value: _formatearMoneda(ticketPromedio)))),
              ],
            );
          },
        ),
        const SizedBox(height: 24),


        // Buscador y Controladores de Filtros (REMOVIDO SHOPIFY)
        Container(
          padding: EdgeInsets.all(isDesktop ? 0 : 16),
          decoration: isDesktop ? null : BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Flex(
            direction: isDesktop ? Axis.horizontal : Axis.vertical,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: isDesktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Container(
                width: isDesktop ? 300 : double.infinity,
                margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16),
                child: TextField(
                  decoration: InputDecoration(hintText: 'Buscar por folio o artículo...', hintStyle: const TextStyle(fontSize: 13), prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)), contentPadding: const EdgeInsets.symmetric(vertical: 0)),
                  onChanged: (val) => setState(() {}),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFiltroPagoHistorial('Todos los Métodos'),
                    _buildFiltroPagoHistorial('Efectivo'),
                    _buildFiltroPagoHistorial('Tarjeta'),
                  ],
                ),
              )
            ],
          ),
        ),
        const SizedBox(height: 24),


        // Grid/Wrap Flexible de la colección de Ventas
        StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('ventas').orderBy('fecha', descending: true).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.receipt_long, size: 48, color: Colors.grey.shade300), const SizedBox(height: 16), const Text('No hay ventas registradas')]));


            var docs = snapshot.data!.docs;
           
            if (_filtroHistorialPagos != 'Todos los Métodos') {
              docs = docs.where((doc) => doc['metodoPago'] == _filtroHistorialPagos).toList();
            }


            return LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth = isDesktop ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;
               
                return Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: docs.map((doc) {
                    return SizedBox(
                      width: cardWidth,
                      child: _buildTicketCard(doc.data() as Map<String, dynamic>),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    );


    // Si es móvil, envolvemos TODO el cuerpo en el scroll principal para que no quede nada estático
    return isDesktop ? Expanded(child: SingleChildScrollView(child: contenidoHistorial)) : SingleChildScrollView(child: contenidoHistorial);
  }


  Widget _buildKPICard({required IconData icon, required Color iconColor, required Color bgColor, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFiltroPagoHistorial(String label) {
    final bool isActive = _filtroHistorialPagos == label;
    return InkWell(
      onTap: () => setState(() => _filtroHistorialPagos = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(color: isActive ? _primaryDark : Colors.white, border: Border.all(color: isActive ? _primaryDark : Colors.grey.shade300), borderRadius: BorderRadius.circular(24)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? Colors.white : Colors.grey.shade700)),
      ),
    );
  }


  Widget _buildTicketCard(Map<String, dynamic> data) {
    final String folio = data['folio'] ?? 'N/A';
    final String metodoPago = data['metodoPago'] ?? 'Efectivo';
    final List items = data['articulos'] ?? [];
    final double total = (data['total'] ?? 0).toDouble();
   
    String fechaFormateada = 'Sin fecha';
    if (data['fecha'] != null) {
      fechaFormateada = _formatearFechaNativa((data['fecha'] as Timestamp).toDate());
    }


    Color badgeBgColor = const Color(0xFFD1FAE5);
    Color badgeTextColor = const Color(0xFF10B981);
   
    if (metodoPago.toLowerCase() == 'tarjeta') {
      badgeBgColor = const Color(0xFFDBEAFE);
      badgeTextColor = const Color(0xFF3B82F6);
    }


    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FOLIO: $folio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _primaryDark)),
                  const SizedBox(height: 6),
                  Row(children: [Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade500), const SizedBox(width: 6), Text(fechaFormateada, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))]),
                ],
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(20)), child: Text(metodoPago.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeTextColor))),
            ],
          ),
         
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFF1F5F9), thickness: 1)),
         
          Text('ARTÍCULOS VENDIDOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(child: Text('${item['cantidad']}x ${item['nombre']}', style: TextStyle(fontSize: 14, color: _primaryDark, fontWeight: FontWeight.w500))),
                Text(_formatearMoneda((item['precio'] * item['cantidad']).toDouble()), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryDark)),
              ],
            ),
          )).toList(),
         
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Color(0xFFF1F5F9), thickness: 1)),
         
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('IMPORTE TOTAL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
                  const SizedBox(height: 6),
                  Text(_formatearMoneda(total), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => _mostrarTicketExito(folio, List<Map<String,dynamic>>.from(items), (data['subtotal'] ?? 0).toDouble(), (data['iva'] ?? 0).toDouble(), total, metodoPago),
                icon: Icon(Icons.receipt_long_outlined, size: 16, color: _primaryDark), label: Text('Ver Ticket', style: TextStyle(color: _primaryDark, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              )
            ],
          )
        ],
      ),
    );
  }
}

