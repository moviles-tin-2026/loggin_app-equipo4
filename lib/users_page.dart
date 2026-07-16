import 'package:flutter/material.dart';
class UsersPage extends StatefulWidget {
  final bool isDesktop;
  const UsersPage({super.key, required this.isDesktop});
  @override
  State<UsersPage> createState() => _UsersPageState();
}
class _UsersPageState extends State<UsersPage> {
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Módulo de Usuarios en construcción...'));
  }
}