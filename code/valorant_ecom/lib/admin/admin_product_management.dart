import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:valo/admin/admin_add_edit_product.dart';
import '../admin/admin_layout.dart';

class AdminProductPage extends StatefulWidget {
  const AdminProductPage({super.key});

  @override
  State<AdminProductPage> createState() => _AdminProductPageState();
}

class _AdminProductPageState extends State<AdminProductPage> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: "Admin Product Management",
      body: Column(
        children: [
          const SizedBox(height: 10),

          // ===== SEARCH BAR =====
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search by name or category",
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white54),
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          const SizedBox(height: 10),

          // ===== ADD PRODUCT BUTTON =====
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddEditProductPage(),
                ),
              );
            },
            child: const Text("Add New Product"),
          ),

          const SizedBox(height: 10),

          // ===== PRODUCT LIST =====
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("products")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                var docs = snapshot.data!.docs;

                // ===== FILTER BASED ON SEARCH =====
                var filteredDocs = docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  var name = (data["name"] ?? "").toString().toLowerCase();
                  var category =
                      (data["category"] ?? "").toString().toLowerCase();
                  return name.contains(searchQuery) ||
                      category.contains(searchQuery);
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (_, index) {
                    var data =
                        filteredDocs[index].data() as Map<String, dynamic>;
                    var id = filteredDocs[index].id;
                    var imagePath = data["image"] ?? "";

                    return Card(
                      color: Colors.white12,
                      child: ListTile(
                        // ===== PRODUCT IMAGE =====
                        leading: imagePath.isNotEmpty
                            ? Image.asset(
                                imagePath,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image_not_supported,
                                size: 50, color: Colors.white70),

                        // ===== PRODUCT NAME =====
                        title: Text(
                          data["name"] ?? "No name",
                          style: const TextStyle(color: Colors.white),
                        ),

                        // ===== CATEGORY & PRICE =====
                        subtitle: Text(
                          "Category: ${data["category"] ?? "N/A"}\nPrice: ${data["price"] ?? "N/A"}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        isThreeLine: true,

                        // ===== EDIT & DELETE =====
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AddEditProductPage(
                                      productId: id,
                                      existingData: data,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                FirebaseFirestore.instance
                                    .collection("products")
                                    .doc(id)
                                    .delete();
                              },
                            ),
                          ],
                        ),
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
}
