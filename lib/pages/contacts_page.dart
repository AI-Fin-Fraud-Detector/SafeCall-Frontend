import 'package:flutter/material.dart';
import 'call_page.dart';

// ── Colors ────────────────────────────────────────────────────────────────────

const _kTeal = Color(0xFF439293);
const _kGreen = Color(0xFF4CAF50);
const _kDarkGreen = Color(0xFF2E7D32);
const _kLightGreen = Color(0xFFF1F8E9);

// ── Phone helpers ─────────────────────────────────────────────────────────────

String _stripPhone(String input) =>
    input.replaceAll(RegExp(r'[^\d]'), '');

String _formatPhone(String input) {
  final d = _stripPhone(input);
  if (d.length == 10) {
    if (d.startsWith('09')) return '${d.substring(0, 4)}-${d.substring(4, 7)}-${d.substring(7)}';
    if (d.startsWith('0800') || d.startsWith('0809')) return '${d.substring(0, 4)}-${d.substring(4, 7)}-${d.substring(7)}';
    return '${d.substring(0, 2)}-${d.substring(2, 6)}-${d.substring(6)}';
  }
  return d.isEmpty ? input : d;
}

// ── Model ─────────────────────────────────────────────────────────────────────

class Contact {
  String name;
  String phone;
  bool isTrusted;
  bool isFrequent;

  Contact({
    required this.name,
    required this.phone,
    this.isTrusted = false,
    this.isFrequent = false,
  });
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  late final List<Contact> _contacts;
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _contacts = [
      Contact(name: 'Daughter Amy', phone: '0912345678', isTrusted: true, isFrequent: true),
      Contact(name: 'Son David', phone: '0923456789', isTrusted: true, isFrequent: true),
      Contact(name: 'Dr. Wang', phone: '0223456789', isTrusted: true),
      Contact(name: 'TWM Customer Service', phone: '0800999888'),
      Contact(name: 'NHI Hotline', phone: '0800030598'),
      Contact(name: 'Unknown Caller', phone: '0223890000'),
    ];
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _matches(Contact c) {
    if (_query.isEmpty) return true;
    return c.name.toLowerCase().contains(_query) || c.phone.contains(_query);
  }

  List<Contact> get _frequent =>
      _contacts.where((c) => c.isFrequent && _matches(c)).toList();
  List<Contact> get _others =>
      _contacts.where((c) => !c.isFrequent && _matches(c)).toList();

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showTrustedDialog(Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Row(
          children: [
            const Icon(Icons.verified_user_rounded, color: _kGreen, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                contact.name,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kLightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: _kDarkGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'In Trusted List',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _kDarkGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Fraud detection will not be activated when calling this contact.',
              style: TextStyle(fontSize: 15, height: 1.65, color: Colors.black87),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _confirmRemoveTrust(contact);
              },
              child: const Text(
                'Remove from Trusted List',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Got It',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmAddTrust(Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: const Text(
          'Add to Trusted List',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Add "${contact.name}" to trusted list?\n\nFraud detection will not activate when calling this contact.',
          style: const TextStyle(fontSize: 15, height: 1.65, color: Colors.black87),
        ),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.black26),
                  foregroundColor: Colors.black54,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() => contact.isTrusted = true);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${contact.name} added to trusted list'),
                    backgroundColor: _kDarkGreen,
                    duration: const Duration(seconds: 2),
                  ));
                },
                child: const Text('Confirm',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _confirmRemoveTrust(Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: const Text(
          'Remove from Trusted List',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Remove "${contact.name}" from trusted list?\n\nFraud detection will activate when calling this contact.',
          style: const TextStyle(fontSize: 15, height: 1.65, color: Colors.black87),
        ),
        actions: [
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.black26),
                  foregroundColor: Colors.black54,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  setState(() => contact.isTrusted = false);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Removed from trusted list'),
                    backgroundColor: Color(0xFF616161),
                    duration: Duration(seconds: 2),
                  ));
                },
                child: const Text('Remove',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Contact context menu ─────────────────────────────────────────────────

  void _showContactMenu(Contact contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    contact.name,
                    style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatPhone(contact.phone),
                    style: const TextStyle(fontSize: 14, color: Colors.black45),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 設為常用 / 移出常用
            ListTile(
              leading: Icon(
                contact.isFrequent ? Icons.star_rounded : Icons.star_outline_rounded,
                color: contact.isFrequent ? const Color(0xFFFFC107) : Colors.black54,
                size: 26,
              ),
              title: Text(
                contact.isFrequent ? 'Remove from Frequent' : 'Add to Frequent',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              onTap: () {
                setState(() => contact.isFrequent = !contact.isFrequent);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(contact.isFrequent
                      ? '${contact.name} added to frequent'
                      : '${contact.name} removed from frequent'),
                  duration: const Duration(seconds: 2),
                ));
              },
            ),
            // 加入信任 / 移出信任
            ListTile(
              leading: Icon(
                contact.isTrusted
                    ? Icons.verified_user_rounded
                    : Icons.shield_outlined,
                color: contact.isTrusted ? _kGreen : Colors.black54,
                size: 26,
              ),
              title: Text(
                contact.isTrusted ? 'Remove from Trusted' : 'Add to Trusted',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
              onTap: () {
                Navigator.pop(ctx);
                if (contact.isTrusted) {
                  _confirmRemoveTrust(contact);
                } else {
                  _confirmAddTrust(contact);
                }
              },
            ),
            // 刪除
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: Colors.red, size: 26),
              title: const Text('Delete Contact',
                  style: TextStyle(fontSize: 16, color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (d) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    title: const Text('Delete Contact',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    content: Text(
                      'Delete "${contact.name}"?',
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                    actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    actions: [
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: Colors.black26),
                              foregroundColor: Colors.black54,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () => Navigator.pop(d),
                            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              setState(() => _contacts.remove(contact));
                              Navigator.pop(d);
                            },
                            child: const Text('Delete',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ]),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Add contact bottom sheet ──────────────────────────────────────────────

  void _showAddContactSheet() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddContactSheet(
        nameCtrl: nameCtrl,
        phoneCtrl: phoneCtrl,
        onConfirm: (name, phone, isTrusted, isFrequent) {
          setState(() {
            _contacts.add(Contact(
              name: name,
              phone: phone,
              isTrusted: isTrusted,
              isFrequent: isFrequent,
            ));
          });
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('$name added to contacts'),
            backgroundColor: _kTeal,
            duration: const Duration(seconds: 2),
          ));
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final frequent = _frequent;
    final others = _others;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Contacts',
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search contacts',
                hintStyle: const TextStyle(color: Colors.black38),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: Colors.black38, size: 22),
                filled: true,
                fillColor: const Color(0xFFF2F2F7),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Trust info card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _kLightGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: _kDarkGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                            fontSize: 13, color: _kDarkGreen, height: 1.4),
                        children: [
                          TextSpan(text: 'Contacts with a green shield '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Icon(Icons.verified_user_rounded,
                                color: _kDarkGreen, size: 15),
                          ),
                          TextSpan(
                              text: ' are trusted. Calls to them will not trigger fraud detection.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (frequent.isNotEmpty) ...[
                  _SectionHeader(label: 'Frequent'),
                  for (final c in frequent)
                    _ContactTile(
                      contact: c,
                      onTap: () => c.isTrusted
                          ? _showTrustedDialog(c)
                          : Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CallPage(
                                  mode: CallMode.outgoing,
                                  contactName: c.name,
                                  callerNumber: c.phone,
                                ),
                              )),
                      onTrustTap: () => c.isTrusted
                          ? _showTrustedDialog(c)
                          : _confirmAddTrust(c),
                      onMenuTap: () => _showContactMenu(c),
                      onStarTap: () {
                        setState(() => c.isFrequent = !c.isFrequent);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(c.isFrequent
                              ? '${c.name} added to frequent contacts'
                              : '${c.name} removed from frequent contacts'),
                          duration: const Duration(seconds: 2),
                        ));
                      },
                    ),
                ],
                if (others.isNotEmpty) ...[
                  _SectionHeader(label: 'Others'),
                  for (final c in others)
                    _ContactTile(
                      contact: c,
                      onTap: () => c.isTrusted
                          ? _showTrustedDialog(c)
                          : Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CallPage(
                                  mode: CallMode.outgoing,
                                  contactName: c.name,
                                  callerNumber: c.phone,
                                ),
                              )),
                      onTrustTap: () => c.isTrusted
                          ? _showTrustedDialog(c)
                          : _confirmAddTrust(c),
                      onMenuTap: () => _showContactMenu(c),
                      onStarTap: () {
                        setState(() => c.isFrequent = !c.isFrequent);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(c.isFrequent
                              ? '${c.name} added to frequent contacts'
                              : '${c.name} removed from frequent contacts'),
                          duration: const Duration(seconds: 2),
                        ));
                      },
                    ),
                ],
                if (frequent.isEmpty && others.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text(
                        'No contacts found',
                        style:
                            TextStyle(fontSize: 16, color: Colors.black38),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: _kTeal,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _showAddContactSheet,
                    icon: const Icon(Icons.person_add_rounded, size: 22),
                    label: const Text(
                      'Add Contact',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black45,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Contact tile ──────────────────────────────────────────────────────────────

class _ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;
  final VoidCallback onTrustTap;
  final VoidCallback onMenuTap;
  final VoidCallback onStarTap;
  const _ContactTile(
      {required this.contact,
      required this.onTap,
      required this.onTrustTap,
      required this.onMenuTap,
      required this.onStarTap});

  @override
  Widget build(BuildContext context) {
    final bool trusted = contact.isTrusted;
    final Color avatarBg =
        trusted ? const Color(0xFFE8F5E9) : const Color(0xFFF2F2F7);
    final Color avatarFg =
        trusted ? _kDarkGreen : Colors.black45;

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              // Star button (direct frequent toggle)
              GestureDetector(
                onTap: onStarTap,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Icon(
                    contact.isFrequent
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 26,
                    color: contact.isFrequent
                        ? const Color(0xFFFFC107)
                        : Colors.black26,
                  ),
                ),
              ),
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: avatarBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  contact.name.characters.first,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: avatarFg,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Name + phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatPhone(contact.phone),
                      style: const TextStyle(
                          fontSize: 14, color: Colors.black45),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Trust badge
              GestureDetector(
                onTap: onTrustTap,
                child: trusted
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF81C784)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.verified_user_rounded,
                                color: _kGreen, size: 16),
                            SizedBox(width: 4),
                            Text('Trusted',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _kDarkGreen,
                                )),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black26),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_rounded,
                                color: Colors.black45, size: 16),
                            SizedBox(width: 4),
                            Text('Trust',
                                style: TextStyle(
                                    fontSize: 13, color: Colors.black54)),
                          ],
                        ),
                      ),
              ),
              // ⋮ menu button
              GestureDetector(
                onTap: onMenuTap,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(8, 8, 0, 8),
                  child: Icon(Icons.more_vert_rounded,
                      size: 22, color: Colors.black38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add contact sheet ─────────────────────────────────────────────────────────

class _AddContactSheet extends StatefulWidget {
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final void Function(String name, String phone, bool isTrusted, bool isFrequent) onConfirm;

  const _AddContactSheet({
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.onConfirm,
  });

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  bool _addToTrust = false;
  bool _addToFrequent = false;

  InputDecoration _fieldDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38),
        filled: true,
        fillColor: const Color(0xFFF2F2F7),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 20,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add Contact',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.black87),
          ),
          const SizedBox(height: 20),

          // Name
          const Text('Name',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 8),
          TextField(
            controller: widget.nameCtrl,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            decoration: _fieldDeco('e.g. Mom, Amy'),
          ),
          const SizedBox(height: 16),

          // Phone
          const Text('Phone Number',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(height: 8),
          TextField(
            controller: widget.phoneCtrl,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
            decoration: _fieldDeco('e.g. 0912-345-678'),
          ),
          const SizedBox(height: 20),

          // Trust toggle card
          GestureDetector(
            onTap: () => setState(() => _addToTrust = !_addToTrust),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _addToTrust ? _kLightGreen : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _addToTrust ? _kGreen : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _addToTrust
                        ? Icons.verified_user_rounded
                        : Icons.shield_outlined,
                    color: _addToTrust ? _kDarkGreen : Colors.black38,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to Trusted List',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _addToTrust ? _kDarkGreen : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Calls to this contact will not trigger fraud detection',
                          style: TextStyle(
                            fontSize: 12,
                            color: _addToTrust
                                ? const Color(0xFF558B2F)
                                : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _addToTrust,
                    onChanged: (v) => setState(() => _addToTrust = v),
                    activeThumbColor: _kGreen,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Frequent toggle card
          GestureDetector(
            onTap: () => setState(() => _addToFrequent = !_addToFrequent),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _addToFrequent
                    ? const Color(0xFFFFFDE7)
                    : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _addToFrequent
                      ? const Color(0xFFFFC107)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _addToFrequent
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: _addToFrequent
                        ? const Color(0xFFFFC107)
                        : Colors.black38,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add to Frequent Contacts',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: _addToFrequent
                                ? const Color(0xFF795548)
                                : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Will appear at the top of your contacts list',
                          style: TextStyle(
                            fontSize: 12,
                            color: _addToFrequent
                                ? const Color(0xFF8D6E63)
                                : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _addToFrequent,
                    onChanged: (v) => setState(() => _addToFrequent = v),
                    activeThumbColor: const Color(0xFFFFC107),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _kTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              onPressed: () {
                final name = widget.nameCtrl.text.trim();
                final phone = _stripPhone(widget.phoneCtrl.text.trim());
                if (name.isEmpty || phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter name and phone number')),
                  );
                  return;
                }
                widget.onConfirm(name, phone, _addToTrust, _addToFrequent);
              },
              child: const Text(
                'Add Contact',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }
}
