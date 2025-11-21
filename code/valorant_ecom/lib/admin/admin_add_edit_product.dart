import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddEditProductPage extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? existingData;

  const AddEditProductPage({super.key, this.productId, this.existingData});

  @override
  State<AddEditProductPage> createState() => _AddEditProductPageState();
}

class _AddEditProductPageState extends State<AddEditProductPage> {
  final _formKey = GlobalKey<FormState>();

  final name = TextEditingController();
  final desc = TextEditingController();
  final price = TextEditingController();
  final image = TextEditingController();
  final color = TextEditingController();
  final type = TextEditingController();
  final size = TextEditingController();
  final measurement = TextEditingController();

  // For dropdown
  String? selectedCategory;

  final List<String> categories = [
    "Computer_Accessory",
    "Clothing",
    "Bag",
    "Stationery",
    "Toy_figurines",
    "Fashion_Accessory",
  ];

  @override
  void initState() {
    super.initState();

    if (widget.existingData != null) {
      name.text = widget.existingData!["name"];
      desc.text = widget.existingData!["desc"];
      price.text = widget.existingData!["price"];
      image.text = widget.existingData!["image"];
      color.text = widget.existingData!["color"];
      type.text = widget.existingData!["type"];
      size.text = widget.existingData!["size"];
      measurement.text = widget.existingData!["measurement"];
      selectedCategory = widget.existingData!["category"];
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isEditing = widget.productId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? "Edit Product" : "Add Product"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // REQUIRED
              buildRequiredField("Name", name),
              buildOptionalField("Description", desc),
              buildRequiredField("Price", price),
              buildOptionalField("Image Path", image),

              // OPTIONAL
              buildOptionalField("Color (comma separated)", color),
              buildOptionalField("Type", type),

              // ===== CATEGORY DROPDOWN (DARK-THEMED) =====
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                dropdownColor: Colors.grey[900], // dark dropdown menu
                decoration: InputDecoration(
                  labelText: "Category",
                  labelStyle: const TextStyle(color: Colors.white),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white54),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.white),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                style: const TextStyle(color: Colors.white), // selected text
                items: categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Text(
                            cat,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ))
                    .toList(),
                validator: (value) =>
                    value == null || value.isEmpty ? "Required" : null,
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
              ),

              // OPTIONAL
              buildOptionalField("Size (comma separated)", size),
              buildOptionalField("Measurement (comma separated)", measurement),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    saveProduct(isEditing);
                  }
                },
                child: Text(isEditing ? "Save Changes" : "Add Product"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // REQUIRED FIELD (with validation)
  Widget buildRequiredField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white54),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        style: const TextStyle(color: Colors.white),
        validator: (v) => v!.isEmpty ? "Required" : null,
      ),
    );
  }

  // OPTIONAL FIELD (no validation)
  Widget buildOptionalField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white54),
          ),
          focusedBorder: const OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  void saveProduct(bool isEditing) async {
    final data = {
      "name": name.text,
      "desc": desc.text,
      "price": price.text,
      "image": image.text,
      "color": color.text,
      "type": type.text,
      "category": selectedCategory,
      "size": size.text,
      "measurement": measurement.text,
    };

    final collection = FirebaseFirestore.instance.collection("products");

    if (isEditing) {
      await collection.doc(widget.productId).update(data);
    } else {
      await collection.add(data);
    }

    Navigator.pop(context);
  }
}
