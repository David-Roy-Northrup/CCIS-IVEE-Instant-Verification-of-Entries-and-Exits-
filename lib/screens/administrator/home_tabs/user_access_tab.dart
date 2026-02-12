import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../widgets/action_feedback.dart';
import 'add_user_access_screen.dart';
import 'edit_user_access_screen.dart';

class UserAccessTab extends StatefulWidget {
  const UserAccessTab({super.key});

  @override
  State<UserAccessTab> createState() => _UserAccessTabState();
}

class _UserAccessTabState extends State<UserAccessTab> {
  final TextEditingController _searchController = TextEditingController();

  String get _currentUserEmail =>
      (FirebaseAuth.instance.currentUser?.email ?? '').trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _deriveNameFromEmail(String email) {
    final e = email.trim().toLowerCase();
    if (!e.contains('@')) return email;
    final local = e.split('@').first;
    final cleaned = local.replaceAll(RegExp(r'[\._\-]+'), ' ').trim();
    if (cleaned.isEmpty) return email;
    return cleaned
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1))
        .join(' ');
  }

  Future<void> _feedbackSuccess(
    String title,
    String message, {
    List<String> affected = const [],
  }) async {
    if (!mounted) return;
    await ActionFeedbackOverlay.show(
      context,
      success: true,
      title: title,
      message: message,
      affected: affected,
    );
  }

  Future<void> _feedbackError(
    String title,
    String message, {
    List<String> affected = const [],
  }) async {
    if (!mounted) return;
    await ActionFeedbackOverlay.show(
      context,
      success: false,
      title: title,
      message: message,
      affected: affected,
    );
  }

  Widget _whitePane({required Widget child}) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _roleChip(String text, {Color? bg, Color? fg, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg ?? Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg ?? Colors.black87),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: fg ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(String q, String name, String email) {
    if (q.isEmpty) return true;
    final haystack = '${name.toLowerCase()} ${email.toLowerCase()}';
    return haystack.contains(q);
  }

  // 0) Current user (always first)
  // 1) Admin only
  // 2) Admin & Operator
  // 3) Operator only
  // 4) No roles / others
  int _accessRank({
    required String email,
    required bool isAdmin,
    required bool isOperator,
  }) {
    final e = email.trim().toLowerCase();
    if (_currentUserEmail.isNotEmpty && e == _currentUserEmail) return 0;
    if (isAdmin && !isOperator) return 1;
    if (isAdmin && isOperator) return 2;
    if (!isAdmin && isOperator) return 3;
    return 4;
  }

  Widget _profileAvatar({
    required String name,
    required String? photoUrl,
    required bool isMe,
  }) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.grey.shade200,
      backgroundImage: (photoUrl != null && photoUrl.trim().isNotEmpty)
          ? NetworkImage(photoUrl)
          : null,
      child: (photoUrl == null || photoUrl.trim().isEmpty)
          ? Text(
              name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: isMe ? Colors.black : Colors.black87,
              ),
            )
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.trim().toLowerCase();

    return _whitePane(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: _searchController.text.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: () => _searchController.clear(),
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Add button (Events tab style)
              IconButton(
                tooltip: 'Add User',
                iconSize: 26,
                icon: const Icon(Icons.add_circle, color: Colors.green),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddUserAccessScreen(),
                    ),
                  );

                  if (result is Map && result['added'] == true) {
                    final email = (result['email'] ?? '').toString();
                    final admin = result['administrator'] == true;
                    final op = result['operator'] == true;

                    await _feedbackSuccess(
                      'User added',
                      'Access for $email created successfully.',
                      affected: [
                        'Roles: ${[if (admin) 'Administrator', if (op) 'Operator', if (!admin && !op) 'None'].join(', ')}',
                      ],
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.toList();

                // filter first
                final filtered = docs.where((d) {
                  final m = (d.data() as Map<String, dynamic>);
                  final email = (m['email'] ?? d.id).toString();
                  final nameRaw = (m['name'] ?? '').toString().trim();
                  final name = nameRaw.isEmpty
                      ? _deriveNameFromEmail(email)
                      : nameRaw;
                  return _matchesSearch(q, name, email);
                }).toList();

                // sort by rank, then name/email
                filtered.sort((a, b) {
                  final am = (a.data() as Map<String, dynamic>);
                  final bm = (b.data() as Map<String, dynamic>);

                  final aEmail = (am['email'] ?? a.id).toString();
                  final bEmail = (bm['email'] ?? b.id).toString();

                  final aAdmin = am['administrator'] == true;
                  final aOp = am['operator'] == true;
                  final bAdmin = bm['administrator'] == true;
                  final bOp = bm['operator'] == true;

                  final ar = _accessRank(
                    email: aEmail,
                    isAdmin: aAdmin,
                    isOperator: aOp,
                  );
                  final br = _accessRank(
                    email: bEmail,
                    isAdmin: bAdmin,
                    isOperator: bOp,
                  );
                  if (ar != br) return ar.compareTo(br);

                  final aNameRaw = (am['name'] ?? '').toString().trim();
                  final bNameRaw = (bm['name'] ?? '').toString().trim();
                  final aName = aNameRaw.isEmpty
                      ? _deriveNameFromEmail(aEmail)
                      : aNameRaw;
                  final bName = bNameRaw.isEmpty
                      ? _deriveNameFromEmail(bEmail)
                      : bNameRaw;

                  final ax = aName.toLowerCase().trim().isEmpty
                      ? aEmail.toLowerCase()
                      : aName.toLowerCase();
                  final bx = bName.toLowerCase().trim().isEmpty
                      ? bEmail.toLowerCase()
                      : bName.toLowerCase();

                  return ax.compareTo(bx);
                });

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      q.isEmpty ? 'No users found.' : 'No results for "$q".',
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final doc = filtered[i];
                    final data = (doc.data() as Map<String, dynamic>);

                    final email = (data['email'] ?? doc.id).toString();
                    final nameRaw = (data['name'] ?? '').toString().trim();
                    final name = nameRaw.isEmpty
                        ? _deriveNameFromEmail(email)
                        : nameRaw;

                    final photoUrl =
                        (data['photoUrl'] ?? data['photoURL'] ?? '')
                            .toString()
                            .trim();

                    final isAdmin = data['administrator'] == true;
                    final isOperator = data['operator'] == true;

                    final isMe =
                        _currentUserEmail.isNotEmpty &&
                        email.trim().toLowerCase() == _currentUserEmail;

                    final roles = <Widget>[
                      if (isAdmin)
                        _roleChip(
                          'Administrator',
                          bg: Colors.blue.shade50,
                          fg: Colors.blue.shade800,
                          icon: Icons.admin_panel_settings,
                        ),
                      if (isOperator)
                        _roleChip(
                          'Operator',
                          bg: Colors.green.shade50,
                          fg: Colors.green.shade800,
                          icon: Icons.qr_code_scanner,
                        ),
                      if (!isAdmin && !isOperator)
                        _roleChip(
                          'No roles',
                          bg: Colors.red.shade50,
                          fg: Colors.red.shade700,
                          icon: Icons.block,
                        ),
                    ];

                    return Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _profileAvatar(
                              name: name,
                              photoUrl: photoUrl.isEmpty ? null : photoUrl,
                              isMe: isMe,
                            ),
                            const SizedBox(width: 10),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: roles,
                                  ),
                                ],
                              ),
                            ),

                            IconButton(
                              tooltip: isMe
                                  ? 'You cannot edit your own access'
                                  : 'Edit',
                              icon: Icon(
                                Icons.edit,
                                color: isMe ? Colors.black26 : Colors.black54,
                              ),
                              onPressed: isMe
                                  ? null
                                  : () async {
                                      final result = await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => EditUserAccessScreen(
                                            email: email,
                                            initialData: data,
                                          ),
                                        ),
                                      );

                                      if (result is Map) {
                                        if (result['updated'] == true) {
                                          final admin =
                                              result['administrator'] == true;
                                          final op = result['operator'] == true;

                                          await _feedbackSuccess(
                                            'User updated',
                                            "$email's roles were updated successfully.",
                                            affected: [
                                              'Roles: ${[if (admin) 'Administrator', if (op) 'Operator', if (!admin && !op) 'None'].join(', ')}',
                                            ],
                                          );
                                        } else if (result['deleted'] == true) {
                                          await _feedbackSuccess(
                                            'User removed',
                                            '$email was deleted successfully.',
                                          );
                                        } else if (result['error'] != null) {
                                          await _feedbackError(
                                            'Action failed',
                                            'Unable to complete request.',
                                          );
                                        }
                                      }
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
