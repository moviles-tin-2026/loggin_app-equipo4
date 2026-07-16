import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'login_page.dart';
import 'sales_page.dart';
import 'users_page.dart';


class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});


  @override
  State<InventoryPage> createState() => _InventoryPageState();
}


class _InventoryPageState extends State<InventoryPage> {
  // CONTROLADORES INVENTARIO
  final _nombreProductoController = TextEditingController();
  final _marcaController = TextEditingController();
  final _stockInicialController = TextEditingController();
  final _stockMinimoController = TextEditingController();
  final _precioController = TextEditingController();
  final _searchController = TextEditingController();
 
  // VARIABLES DE ESTADO INVENTARIO
  String _busquedaQuery = '';
  final List<String> _categorias = ['Computadoras y laptops', 'Componentes', 'Periféricos', 'Audio', 'Accesorios'];
  String? _categoriaSeleccionada;
  String _filtroActual = 'Todos';


  // VARIABLES DE IMAGEN
  final ImagePicker _picker = ImagePicker();
  XFile? _imagenSeleccionada;
  bool _isSubiendoImagen = false;


  // SERVICIOS
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
 
  // AHORA ARRANCA EN 0 (VISTA GENERAL)
  int _selectedIndex = 0;


  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();


  // COLORES BRANDING
  final Color _primaryDark = const Color(0xFF0F172A);
  final Color _accentGreen = const Color(0xFF059669);
  final Color _bgLight = const Color(0xFFF8FAFC);


  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _busquedaQuery = _searchController.text.toLowerCase());
    });
  }


  @override
  void dispose() {
    _nombreProductoController.dispose();
    _marcaController.dispose();
    _stockInicialController.dispose();
    _stockMinimoController.dispose();
    _precioController.dispose();
    _searchController.dispose();
    super.dispose();
  }


  String _formatearMoneda(double cantidad) {
    List<String> partes = cantidad.toStringAsFixed(2).split('.');
    RegExp reg = RegExp(r'\B(?=(\d{3})+(?!\d))');
    partes[0] = partes[0].replaceAll(reg, ',');
    return '\$${partes.join('.')}';
  }


  // =======================================================
  // FUNCIONES DE INVENTARIO (CRUD)
  // =======================================================
  Future<void> _guardarOActualizarProducto(BuildContext dialogContext, StateSetter setStateDialog, {String? editDocId, String? urlImagenExistente}) async {
    final nombre = _nombreProductoController.text.trim();
    final marca = _marcaController.text.trim();
    final stockInicialTexto = _stockInicialController.text.trim();
    final stockMinimoTexto = _stockMinimoController.text.trim();
    final precioTexto = _precioController.text.trim();


    if (nombre.isEmpty || marca.isEmpty || _categoriaSeleccionada == null || stockInicialTexto.isEmpty || stockMinimoTexto.isEmpty || precioTexto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Completa todos los campos'), backgroundColor: Colors.red));
      return;
    }


    final stockInicial = int.tryParse(stockInicialTexto);
    final stockMinimo = int.tryParse(stockMinimoTexto);
    final precio = double.tryParse(precioTexto);


    if (stockInicial == null || stockMinimo == null || precio == null) return;


    setStateDialog(() => _isSubiendoImagen = true);
    String urlImagenFinal = urlImagenExistente ?? '';


    try {
      if (_imagenSeleccionada != null) {
        final String nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        final Reference ref = _storage.ref().child('productos').child(nombreArchivo);
        final bytes = await _imagenSeleccionada!.readAsBytes();
        if (kIsWeb) {
          await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
        } else {
          await ref.putData(bytes);
        }
        urlImagenFinal = await ref.getDownloadURL();
      }


      final Map<String, dynamic> datosProducto = {
        'nombre': nombre, 'marca': marca, 'categoria': _categoriaSeleccionada,
        'cantidad': stockInicial, 'stockMinimo': stockMinimo, 'precio': precio,
        'urlImagen': urlImagenFinal, 'usuarioId': FirebaseAuth.instance.currentUser?.uid,
      };


      if (editDocId == null) {
        datosProducto['fechaCreacion'] = FieldValue.serverTimestamp();
        await _firestore.collection('inventarios').add(datosProducto);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto registrado'), backgroundColor: Colors.green));
      } else {
        await _firestore.collection('inventarios').doc(editDocId).update(datosProducto);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Producto actualizado'), backgroundColor: Colors.indigo));
      }
      Navigator.pop(dialogContext);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      setStateDialog(() => _isSubiendoImagen = false);
    }
  }


  Future<void> _ajustarStock(String docId, int cantidadActual, int ajuste) async {
    final nuevaCantidad = cantidadActual + ajuste;
    if (nuevaCantidad < 0) return;
    await _firestore.collection('inventarios').doc(docId).update({'cantidad': nuevaCantidad});
  }


  Future<void> _eliminarProducto(String docId) async {
    await _firestore.collection('inventarios').doc(docId).delete();
  }


  void _mostrarConfirmacionEliminar(String docId, String nombreProducto) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(children: const [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 12), Text('¿Eliminar artículo?', style: TextStyle(fontWeight: FontWeight.bold))]),
          content: Text('¿Deseas eliminar "$nombreProducto"? Esta acción no se puede deshacer.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white), onPressed: () { Navigator.pop(dialogContext); _eliminarProducto(docId); }, child: const Text('Eliminar')),
          ],
        );
      },
    );
  }


  void _mostrarFormularioProducto({String? docId, Map<String, dynamic>? productData}) {
    final bool isEditing = docId != null && productData != null;
    if (isEditing) {
      _nombreProductoController.text = productData['nombre'] ?? '';
      _marcaController.text = productData['marca'] ?? '';
      _categoriaSeleccionada = productData['categoria'];
      _stockInicialController.text = (productData['cantidad'] ?? 0).toString();
      _stockMinimoController.text = (productData['stockMinimo'] ?? 0).toString();
      _precioController.text = (productData['precio'] ?? 0).toString();
    } else {
      _nombreProductoController.clear(); _marcaController.clear(); _categoriaSeleccionada = null;
      _stockInicialController.clear(); _stockMinimoController.clear(); _precioController.clear();
    }
    _imagenSeleccionada = null; _isSubiendoImagen = false;


    showDialog(
      context: context, barrierDismissible: !_isSubiendoImagen,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), insetPadding: const EdgeInsets.all(16),
              child: Container(
                width: 460, padding: const EdgeInsets.all(24),
                child: _isSubiendoImagen ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isEditing ? Colors.indigo.withOpacity(0.1) : _accentGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(isEditing ? Icons.edit_outlined : Icons.add_photo_alternate_outlined, color: isEditing ? Colors.indigo : _accentGreen)),
                          const SizedBox(width: 16),
                          Expanded(child: Text(isEditing ? 'Editar Producto' : 'Añadir Nuevo Producto', style: TextStyle(color: _primaryDark, fontSize: 18, fontWeight: FontWeight.bold))),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            final XFile? foto = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                            if (foto != null) setStateDialog(() => _imagenSeleccionada = foto);
                          },
                          child: Container(
                            width: double.infinity, height: 120,
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                            child: _imagenSeleccionada != null
                                ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_imagenSeleccionada!.path, fit: BoxFit.cover))
                                : (isEditing && (productData['urlImagen'] ?? '').isNotEmpty)
                                    ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(productData['urlImagen'], fit: BoxFit.cover))
                                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.cloud_upload_outlined, color: isEditing ? Colors.indigo : _accentGreen, size: 28), const SizedBox(height: 8), const Text('Haz clic para actualizar foto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))]),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: _nombreProductoController, decoration: InputDecoration(labelText: 'Nombre', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _marcaController, decoration: InputDecoration(labelText: 'Marca', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                          const SizedBox(width: 16),
                          Expanded(child: DropdownButtonFormField<String>(value: _categoriaSeleccionada, decoration: InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))), items: _categorias.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) => setStateDialog(() => _categoriaSeleccionada = v))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: _stockInicialController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Stock Actual', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                          const SizedBox(width: 16),
                          Expanded(child: TextField(controller: _stockMinimoController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Stock Mínimo', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(controller: _precioController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Precio Unitario', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                      const SizedBox(height: 32),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                          const SizedBox(width: 8),
                          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: isEditing ? Colors.indigo : _accentGreen, foregroundColor: Colors.white), onPressed: () => _guardarOActualizarProducto(dialogContext, setStateDialog, editDocId: docId, urlImagenExistente: productData?['urlImagen']), child: Text(isEditing ? 'Actualizar' : 'Guardar')),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        );
      },
    );
  }


  // =======================================================
  // ESTRUCTURA BASE DE LA PANTALLA (SIDEBAR Y HEADER)
  // =======================================================
  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      key: _scaffoldKey, backgroundColor: _bgLight, drawer: isDesktop ? null : Drawer(child: _buildSidebar()),
      body: Row(
        children: [
          if (isDesktop) _buildSidebar(),
          Expanded(child: Column(children: [_buildHeader(isDesktop), Expanded(child: _buildBodyContent(isDesktop))])),
        ],
      ),
    );
  }


  Widget _buildBodyContent(bool isDesktop) {
    if (_selectedIndex == 0) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.dashboard_customize_outlined, size: 64, color: Colors.grey.shade300), const SizedBox(height: 16), Text('Vista General en construcción', style: TextStyle(fontSize: 20, color: Colors.grey.shade400, fontWeight: FontWeight.bold))]));
    }
    if (_selectedIndex == 1) return _buildInventoryView(isDesktop);
    if (_selectedIndex == 2) return SalesPage(isDesktop: isDesktop);
    if (_selectedIndex == 3) return UsersPage(isDesktop: isDesktop);
   
    return Container();
  }


  // -------------------------------------------------------
  // VISTA INVENTARIO
  // -------------------------------------------------------
  Widget _buildInventoryView(bool isDesktop) {
    return Padding(
      padding: EdgeInsets.all(isDesktop ? 32.0 : 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDesktop)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Control de Existencias e Inventario', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _primaryDark)),
                    const SizedBox(height: 4),
                    const Text('Agrega productos, edita existencias y gestiona alertas.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _mostrarFormularioProducto(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Añadir Nuevo Producto'),
                  style: ElevatedButton.styleFrom(backgroundColor: _accentGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Control de Existencias e\nInventario', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _primaryDark)),
                const SizedBox(height: 8),
                const Text('Agrega productos, edita existencias en tiempo real y gestiona alertas.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _mostrarFormularioProducto(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Añadir Nuevo Producto'),
                    style: ElevatedButton.styleFrom(backgroundColor: _accentGreen, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                ),
              ],
            ),
         
          const SizedBox(height: 24),


          StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('inventarios').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
             
              double valorTotal = 0;
              int unidadesTotales = 0;
              int catalogoActivo = snapshot.data!.docs.length;
              int alertasStock = 0;


              for (var doc in snapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final int cantidad = data['cantidad'] ?? 0;
                final double precio = (data['precio'] ?? 0).toDouble();
                final int stockMinimo = data['stockMinimo'] ?? 0;


                valorTotal += (cantidad * precio);
                unidadesTotales += cantidad;
                if (cantidad <= stockMinimo) {
                  alertasStock++;
                }
              }


              return Column(
                children: [
                  if (isDesktop)
                    Row(
                      children: [
                        Expanded(child: _buildKPICard(icon: Icons.attach_money, iconColor: _accentGreen, bgColor: _accentGreen.withOpacity(0.1), title: 'VALOR DE INVENTARIO', value: _formatearMoneda(valorTotal), subtitle: 'Pesos Mexicanos (MXN)', isDesktop: isDesktop)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildKPICard(icon: Icons.widgets_outlined, iconColor: _primaryDark, bgColor: _primaryDark.withOpacity(0.05), title: 'UNIDADES FÍSICAS', value: '$unidadesTotales pzs', subtitle: 'Total de existencias en bodega', isDesktop: isDesktop)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildKPICard(icon: Icons.inventory_2_outlined, iconColor: _primaryDark, bgColor: _primaryDark.withOpacity(0.05), title: 'CATÁLOGO ACTIVO', value: '$catalogoActivo items', subtitle: 'Productos registrados únicos', isDesktop: isDesktop)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildKPICard(icon: Icons.warning_amber_rounded, iconColor: Colors.red.shade600, bgColor: Colors.red.withOpacity(0.1), title: 'ALERTAS DE STOCK', value: '$alertasStock bajos', subtitle: 'Requiere reabastecimiento urgente', isDesktop: isDesktop)),
                      ],
                    )
                  else
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _buildKPICard(icon: Icons.attach_money, iconColor: _accentGreen, bgColor: _accentGreen.withOpacity(0.1), title: 'VALOR TOTAL', value: _formatearMoneda(valorTotal), subtitle: 'En MXN', isDesktop: isDesktop)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKPICard(icon: Icons.widgets_outlined, iconColor: _primaryDark, bgColor: _primaryDark.withOpacity(0.05), title: 'UNIDADES', value: '$unidadesTotales pzs', subtitle: 'En bodega', isDesktop: isDesktop)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _buildKPICard(icon: Icons.inventory_2_outlined, iconColor: _primaryDark, bgColor: _primaryDark.withOpacity(0.05), title: 'CATÁLOGO', value: '$catalogoActivo items', subtitle: 'Registrados', isDesktop: isDesktop)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildKPICard(icon: Icons.warning_amber_rounded, iconColor: Colors.red.shade600, bgColor: Colors.red.withOpacity(0.1), title: 'ALERTAS', value: '$alertasStock bajos', subtitle: 'Reabastecer', isDesktop: isDesktop)),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),


          Container(
            padding: EdgeInsets.all(isDesktop ? 0 : 16),
            decoration: isDesktop ? null : BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200)
            ),
            child: Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              children: [
                Container(
                  width: isDesktop ? 300 : double.infinity,
                  margin: EdgeInsets.only(bottom: isDesktop ? 0 : 16, right: isDesktop ? 16 : 0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre...',
                      hintStyle: const TextStyle(fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                      suffixIcon: _busquedaQuery.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => _searchController.clear())
                          : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                  ),
                ),
                Expanded(
                  flex: isDesktop ? 1 : 0,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterPill('Todos'),
                        _buildFilterPill('Bajo stock'),
                        ..._categorias.map((c) => _buildFilterPill(c)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
         
          if (isDesktop) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
              child: Row(
                children: const [
                  Expanded(flex: 4, child: Text('PRODUCTO / MARCA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Expanded(flex: 2, child: Text('CATEGORÍA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Expanded(flex: 2, child: Text('PRECIO (MXN)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Expanded(flex: 3, child: Text('INVENTARIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                  SizedBox(width: 80, child: Text('ACCIONES', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey))),
                ],
              ),
            ),
            const Divider(height: 1),
          ],


          Expanded(
            child: Container(
              decoration: isDesktop ? BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
              ) : null,
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('inventarios').orderBy('fechaCreacion', descending: true).snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text('Error al cargar datos'));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                 
                  var docs = snapshot.data!.docs;
                 
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String nombreProducto = (data['nombre'] ?? '').toString().toLowerCase();
                   
                    bool cumpleFiltro = true;
                    if (_filtroActual == 'Bajo stock') {
                      final int cant = data['cantidad'] ?? 0;
                      final int min = data['stockMinimo'] ?? 0;
                      cumpleFiltro = cant <= min;
                    } else if (_filtroActual != 'Todos') {
                      final String cat = data['categoria'] ?? '';
                      cumpleFiltro = cat == _filtroActual;
                    }
                    bool cumpleBusqueda = nombreProducto.contains(_busquedaQuery);
                    return cumpleFiltro && cumpleBusqueda;
                  }).toList();
                 
                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text('No se encontraron productos', style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    );
                  }


                  return ListView.separated(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24.0 : 0, vertical: 8.0),
                    itemCount: docs.length,
                    separatorBuilder: (context, index) => isDesktop ? const Divider() : const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final docId = doc.id;
                      return isDesktop ? _buildProductRow(data, docId) : _buildProductCardMobile(data, docId);
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


  Widget _buildKPICard({required IconData icon, required Color iconColor, required Color bgColor, required String title, required String value, required String subtitle, required bool isDesktop}) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 20 : 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: EdgeInsets.all(isDesktop ? 12 : 10), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: isDesktop ? 24 : 20)),
          SizedBox(width: isDesktop ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: isDesktop ? 11 : 9, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: isDesktop ? 20 : 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)), overflow: TextOverflow.ellipsis),
                if(subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: isDesktop ? 10 : 9, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildProductCardMobile(Map<String, dynamic> data, String docId) {
    final String nombre = data['nombre'] ?? 'Sin nombre';
    final String marca = data['marca'] ?? 'Sin marca';
    final String categoria = data['categoria'] ?? 'General';
    final double precio = (data['precio'] ?? 0).toDouble();
    final int cantidad = data['cantidad'] ?? 0;
    final int stockMinimo = data['stockMinimo'] ?? 0;
    final String urlImagen = data['urlImagen'] ?? '';
   
    final bool bajoStock = cantidad <= stockMinimo;
    final double stockMeta = stockMinimo > 0 ? (stockMinimo * 2).toDouble() : 100.0;
    final double stockPercentage = (cantidad / stockMeta).clamp(0.0, 1.0);
    final Color stockColor = bajoStock ? Colors.red : _accentGreen;


    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: urlImagen.isNotEmpty
                        ? ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(urlImagen, fit: BoxFit.cover))
                        : Icon(Icons.devices, size: 20, color: Colors.grey.shade400),
                  ),
                  const SizedBox(width: 12),
                  Text(nombre, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _primaryDark)),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    icon: Icon(Icons.edit_outlined, size: 20, color: Colors.grey.shade400),
                    onPressed: () => _mostrarFormularioProducto(docId: docId, productData: data),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                    icon: Icon(Icons.delete_outline, size: 20, color: Colors.grey.shade400),
                    onPressed: () => _mostrarConfirmacionEliminar(docId, nombre),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Text(marca, style: TextStyle(fontSize: 10, color: Colors.grey.shade700))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)), child: Text(categoria, style: TextStyle(fontSize: 10, color: Colors.grey.shade700))),
            ],
          ),
          const Padding(padding: EdgeInsets.symmetric(vertical: 12.0), child: Divider()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Precio', style: TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 4),
              Text('${_formatearMoneda(precio)} MXN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _primaryDark)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('INVENTARIO:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                    const SizedBox(width: 8),
                    Text('$cantidad uds', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _primaryDark)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () => _ajustarStock(docId, cantidad, -1),
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: const Icon(Icons.remove, size: 16)),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 16.0), child: Text('Ajustar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    InkWell(
                      onTap: () => _ajustarStock(docId, cantidad, 1),
                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)), child: const Icon(Icons.add, size: 16)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(value: stockPercentage, backgroundColor: Colors.grey.shade200, color: stockColor, minHeight: 6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildProductRow(Map<String, dynamic> data, String docId) {
    final String nombre = data['nombre'] ?? 'Sin nombre';
    final String marca = data['marca'] ?? 'Sin marca';
    final String categoria = data['categoria'] ?? 'General';
    final double precio = (data['precio'] ?? 0).toDouble();
    final int cantidad = data['cantidad'] ?? 0;
    final int stockMinimo = data['stockMinimo'] ?? 0;
    final String urlImagen = data['urlImagen'] ?? '';
   
    final bool bajoStock = cantidad <= stockMinimo;
    final double stockMeta = stockMinimo > 0 ? (stockMinimo * 2).toDouble() : 100.0;
    final double stockPercentage = (cantidad / stockMeta).clamp(0.0, 1.0);
    final Color stockColor = bajoStock ? Colors.red : _accentGreen;


    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(6)),
                  child: urlImagen.isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(6), child: Image.network(urlImagen, fit: BoxFit.cover))
                      : Icon(Icons.devices, size: 18, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)), child: Text(marca, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)))
                    ]
                  ),
                ),
              ],
            )
          ),
          Expanded(flex: 2, child: Align(alignment: Alignment.centerLeft, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)), child: Text(categoria, style: const TextStyle(fontSize: 11))))),
          Expanded(flex: 2, child: Text(_formatearMoneda(precio), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text('$cantidad uds', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)), if (bajoStock) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)), child: Text('Bajo Stock', style: TextStyle(fontSize: 9, color: Colors.red.shade700)))]]), const SizedBox(height: 6), LinearProgressIndicator(value: stockPercentage, backgroundColor: Colors.grey.shade200, color: stockColor, minHeight: 4)])),
          SizedBox(
            width: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey.shade500),
                  onPressed: () => _mostrarFormularioProducto(docId: docId, productData: data),
                ),
                const SizedBox(width: 12),
                IconButton(
                  padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  icon: Icon(Icons.delete_outline, size: 18, color: Colors.grey.shade500),
                  onPressed: () => _mostrarConfirmacionEliminar(docId, nombre),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildFilterPill(String label) {
    final bool isActive = _filtroActual == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label), selected: isActive,
        onSelected: (val) { if (val) setState(() => _filtroActual = label); },
        labelStyle: TextStyle(color: isActive ? Colors.white : Colors.grey.shade700, fontSize: 12),
        selectedColor: _primaryDark, backgroundColor: Colors.white,
        side: BorderSide(color: isActive ? _primaryDark : Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }


  Widget _buildSidebar() {
    return Container(
      width: 250, color: _primaryDark,
      child: Column(
        children: [
          const SizedBox(height: 48),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.hub, color: Colors.white, size: 24), SizedBox(width: 12), Text('PyME-Sync', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 48),
         
          _buildSidebarItem(Icons.dashboard_outlined, 'Vista General', 0),
          _buildSidebarItem(Icons.inventory_2, 'Almacén / Inventario', 1),
          _buildSidebarItem(Icons.point_of_sale, 'Registrar Ventas', 2),
          _buildSidebarItem(Icons.people_alt_outlined, 'Usuarios', 3),
         
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: InkWell(
              onTap: () async { await FirebaseAuth.instance.signOut(); if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage())); },
              child: Row(children: const [Icon(Icons.logout, color: Colors.grey, size: 20), SizedBox(width: 12), Text('Salir de la Consola', style: TextStyle(color: Colors.grey, fontSize: 13))]),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildSidebarItem(IconData icon, String title, int index) {
    final isActive = _selectedIndex == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: isActive ? _accentGreen : Colors.transparent, borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(icon, color: isActive ? Colors.white : Colors.grey.shade400, size: 20),
        title: Text(title, style: TextStyle(color: isActive ? Colors.white : Colors.grey.shade400, fontSize: 13, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        dense: true,
        onTap: () { setState(() => _selectedIndex = index); if (MediaQuery.of(context).size.width <= 900) Navigator.pop(context); },
      ),
    );
  }


  Widget _buildHeader(bool isDesktop) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'usuario@correo.com';
    String rawName = user?.displayName ?? email.split('@').first;
    String iniciales = rawName.isNotEmpty ? rawName.substring(0, 2).toUpperCase() : 'US';


    return Container(
      height: 80, padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (!isDesktop) IconButton(icon: const Icon(Icons.menu), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
              Column(
                mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PANEL DE CONTROL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _accentGreen)),
                  Text(
                    _selectedIndex == 0 ? 'Vista General' :
                    _selectedIndex == 1 ? 'Inventario y Almacén' :
                    _selectedIndex == 2 ? 'Punto de Venta POS' : 'Administración de Usuarios',
                    style: TextStyle(fontSize: isDesktop ? 18 : 16, fontWeight: FontWeight.bold, color: _primaryDark)
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              CircleAvatar(backgroundColor: _accentGreen.withOpacity(0.2), radius: 18, child: Text(iniciales, style: TextStyle(color: _accentGreen, fontWeight: FontWeight.bold, fontSize: 14))),
              if (isDesktop) ...[
                const SizedBox(width: 12),
                Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(rawName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)), Text(email, style: TextStyle(fontSize: 11, color: Colors.grey.shade600))]),
              ]
            ],
          )
        ],
      ),
    );
  }
}
