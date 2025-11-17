import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/main.dart'; // SafeImage

class EditCartItemPage extends StatefulWidget {
  final String userId;
  final String cartDocId;
  final Map<String, dynamic> item;

  const EditCartItemPage({
    super.key,
    required this.userId,
    required this.cartDocId,
    required this.item,
  });

  @override
  State<EditCartItemPage> createState() => _EditCartItemPageState();
}

class _EditCartItemPageState extends State<EditCartItemPage> {
  late int quantity;
  String? selectedColor;
  String? selectedSize;
  String? selectedMeasurement;

  List<String> colors = [];
  List<String> sizes = [];
  List<String> measurements = [];

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // Initialize from cart item
    quantity = widget.item['quantity'] ?? 1;
    selectedColor = widget.item['color']?.isNotEmpty == true ? widget.item['color'] : null;
    selectedSize = widget.item['size']?.isNotEmpty == true ? widget.item['size'] : null;
    selectedMeasurement = widget.item['measurement']?.isNotEmpty == true ? widget.item['measurement'] : null;

    _loadProductOptions();
  }

  Future<void> _loadProductOptions() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('name', isEqualTo: widget.item['name'])
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        setState(() => isLoading = false);
        return;
      }

      final data = querySnapshot.docs.first.data();

      setState(() {
        colors = _parseOptions(data['color']);
        sizes = _parseOptions(data['size']);
        measurements = _parseOptions(data['measurement']);

        if (!colors.contains(selectedColor)) selectedColor = null;
        if (!sizes.contains(selectedSize)) selectedSize = null;
        if (!measurements.contains(selectedMeasurement)) selectedMeasurement = null;

        isLoading = false;
      });
    } catch (e) {
      print('Error loading product options: $e');
      setState(() => isLoading = false);
    }
  }

  List<String> _parseOptions(dynamic raw) {
    if (raw == null || raw.toString().trim().isEmpty) return [];
    return raw.toString().split(',').map((e) => e.trim()).toList();
  }

  String _generateCartId() {
    final name = widget.item['name'] ?? '';
    final colorPart = selectedColor ?? '';
    final sizePart = selectedSize ?? '';
    final measurementPart = selectedMeasurement ?? '';
    return '${name}_${colorPart}${sizePart}${measurementPart}';
  }

  Future<void> saveChanges() async {
    final newCartId = _generateCartId();
    final userCartRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('cart');

    try {
      if (widget.cartDocId != newCartId) {
        final existing = await userCartRef.doc(newCartId).get();

        if (existing.exists) {
          final existingQty = existing.data()?['quantity'] ?? 0;
          await userCartRef.doc(newCartId).update({
            'quantity': existingQty + quantity,
            'timestamp': FieldValue.serverTimestamp(),
          });
          await userCartRef.doc(widget.cartDocId).delete();
        } else {
          await userCartRef.doc(newCartId).set({
            'name': widget.item['name'],
            'price': widget.item['price'],
            'image': widget.item['image'],
            'quantity': quantity,
            'color': selectedColor ?? '',
            'size': selectedSize ?? '',
            'measurement': selectedMeasurement ?? '',
            'selected': true,
            'timestamp': FieldValue.serverTimestamp(),
          });
          await userCartRef.doc(widget.cartDocId).delete();
        }
      } else {
        await userCartRef.doc(widget.cartDocId).update({
          'quantity': quantity,
          'color': selectedColor ?? '',
          'size': selectedSize ?? '',
          'measurement': selectedMeasurement ?? '',
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('Error saving cart changes: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save changes')),
        );
      }
    }
  }

  Widget _buildDropdown(String label, List<String> options, String? value, Function(String?) onChanged) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)),
        DropdownButton<String>(
          value: value,
          dropdownColor: Colors.black,
          hint: Text('Select $label', style: const TextStyle(color: Colors.white70)),
          items: options.map((opt) => DropdownMenuItem(
            value: opt,
            child: Text(opt, style: const TextStyle(color: Colors.white)),
          )).toList(),
          onChanged: onChanged,
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.redAccent),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Edit Item"),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: SafeImage(
                      item['image'],
                      width: 200,
                      height: 200,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(item['name'], style: const TextStyle(fontSize: 22, color: Colors.white)),
                  const SizedBox(height: 10),
                  Text("RM ${item['price']}", style: const TextStyle(fontSize: 18, color: Colors.redAccent)),
                  const SizedBox(height: 20),

                  // Dropdowns
                  _buildDropdown("Color", colors, selectedColor, (v) => setState(() => selectedColor = v)),
                  _buildDropdown("Size", sizes, selectedSize, (v) => setState(() => selectedSize = v)),
                  _buildDropdown("Measurement", measurements, selectedMeasurement, (v) => setState(() => selectedMeasurement = v)),

                  // Quantity
                  Row(
                    children: [
                      const Text("Quantity:", style: TextStyle(color: Colors.white, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.remove, color: Colors.white),
                        onPressed: quantity > 1 ? () => setState(() => quantity--) : null,
                      ),
                      Text("$quantity", style: const TextStyle(color: Colors.white, fontSize: 16)),
                      IconButton(
                        icon: const Icon(Icons.add, color: Colors.white),
                        onPressed: () => setState(() => quantity++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                      onPressed: saveChanges,
                      child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Delete Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
                      onPressed: () async {
                        final userCartRef = FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.userId)
                            .collection('cart');
                        try {
                          await userCartRef.doc(widget.cartDocId).delete();
                          if (mounted) Navigator.pop(context, true);
                        } catch (e) {
                          print('Error deleting cart item: $e');
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Failed to delete item')),
                            );
                          }
                        }
                      },
                      child: const Text("Delete Item", style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
