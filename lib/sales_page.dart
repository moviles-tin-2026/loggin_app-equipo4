import 'package:flutter/material.dart';
class SalesPage extends StatefulWidget {
  final bool isDesktop;
  const SalesPage({super.key, required this.isDesktop});
  @override
  State<SalesPage> createState() => _SalesPageState();
}
class _SalesPageState extends State<SalesPage> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Módulo de Ventas en construcción...'));
  }
}