import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'add_user_access_screen.dart';
import 'edit_user_access_screen.dart';

class UserAccessTab extends StatefulWidget {
  const UserAccessTab({super.key});

  @override
  State<UserAccessTab> createState() => _UserAccessTabState();
}

class _UserAccessTabState extends State<UserAccessTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String get _currentUserEmail =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase() ?? "";

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _snack(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color ?? Colors.black87),
    );
  }

  String _deriveNameFromEmail(String email) {
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) return 'Unknown';
    final local = e.split('@').first;
    final cleaned = local.replaceAll(RegExp(r'[\._\-]+'), ' ').trim();
    if (cleaned.isEmpty) return 'Unknown';
    return cleaned
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  Future<void> _deleteUser(
    BuildContext context,
    String docId,
    String email,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text("Delete User"),
        content: Text("Are you sure you want to delete:\n\n$email"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(docId).delete();
      _snack("User deleted.");
    } catch (e) {
      _snack("Error deleting user: $e", color: Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F3C),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "IVEE Users",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Search + Add button row
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search),
                          hintText: "Search User",
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase().trim();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A0F3C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AddUserAccessScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("Add"),
                      ),
                    ),
                  ],
                ),
              ),

              // User list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(
                        child: Text(
                          "Error loading users",
                          style: TextStyle(color: Colors.red),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final docs = snapshot.data?.docs ?? [];

                    final filtered = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final email = (data['email'] ?? doc.id)
                          .toString()
                          .toLowerCase();
                      final name = (data['name'] ?? '')
                          .toString()
                          .toLowerCase();
                      if (_searchQuery.isEmpty) return true;
                      return email.contains(_searchQuery) ||
                          name.contains(_searchQuery);
                    }).toList();

                    filtered.sort((a, b) {
                      final ae =
                          ((a.data() as Map<String, dynamic>)['email'] ?? a.id)
                              .toString()
                              .toLowerCase();
                      final be =
                          ((b.data() as Map<String, dynamic>)['email'] ?? b.id)
                              .toString()
                              .toLowerCase();
                      return ae.compareTo(be);
                    });

                    if (filtered.isEmpty) {
                      return const Center(
                        child: Text(
                          "No users found",
                          style: TextStyle(color: Colors.black54),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final doc = filtered[index];
                        final data = doc.data() as Map<String, dynamic>;

                        final email = (data['email'] ?? doc.id).toString();
                        final storedName = (data['name'] ?? '').toString();
                        final photoUrl = (data['photoUrl'] ?? '').toString();

                        final displayName = storedName.isNotEmpty
                            ? storedName
                            : _deriveNameFromEmail(email);

                        final isAdmin =
                            (data['administrator'] ?? false) == true;
                        final isOperator = (data['operator'] ?? false) == true;

                        final roles = <String>[
                          if (isAdmin) "Administrator",
                          if (isOperator) "Operator",
                        ];

                        final isSelf = email.toLowerCase() == _currentUserEmail;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: Colors.grey[200],
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : "?",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black54,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(email, style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 2),
                              Text(
                                roles.isEmpty ? "No Access" : roles.join(", "),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: isSelf
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                EditUserAccessScreen(
                                                  docId: doc.id,
                                                  data: data,
                                                ),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      onPressed: () =>
                                          _deleteUser(context, doc.id, email),
                                    ),
                                  ],
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
