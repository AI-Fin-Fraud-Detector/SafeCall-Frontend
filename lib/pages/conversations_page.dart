import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../di/service_locator.dart';
import '../models/conversation_models.dart';
import '../services/api_service.dart';
import '../services/conversation_service.dart';
import 'call_summary_page.dart';

const _kTeal = Color(0xFF439293);
const _kTealLight = Color(0xFFE0F2F1);
const _kTealDark = Color(0xFF00695C);

class ConversationsPage extends StatefulWidget {
  const ConversationsPage({super.key});

  @override
  State<ConversationsPage> createState() => _ConversationsPageState();
}

class _ConversationsPageState extends State<ConversationsPage> {
  final _service = ConversationService();
  List<Conversation>? _conversations;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _service.getConversations();
      if (mounted) setState(() => _conversations = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Call History',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 48, color: Colors.black26),
              const SizedBox(height: 16),
              Text('Load Failed',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54)),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _load();
                  },
                  child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_conversations == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_conversations!.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.call_outlined, size: 52, color: Colors.black26),
            SizedBox(height: 16),
            Text('No call history yet',
                style: TextStyle(fontSize: 16, color: Colors.black45)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _conversations!.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 80, endIndent: 16),
        itemBuilder: (context, i) => _ConversationTile(
          conversation: _conversations![i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  _ConversationSummaryPage(conversation: _conversations![i]),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final phone = conversation.metadata?.callerPhoneNumber ?? 'Unknown';
    final name = conversation.metadata?.callerName;
    final local = conversation.createdAt.toLocal();
    final dt =
        '${local.month.toString().padLeft(2, '0')}/${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';

    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                    color: _kTealLight, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: name != null
                    ? Text(
                        name.characters.first,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _kTealDark,
                        ),
                      )
                    : const Icon(Icons.call_received_rounded,
                        color: _kTeal, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name ?? phone,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (name != null) ...[
                      const SizedBox(height: 3),
                      Text(phone,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.black45)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(dt.split(' ')[0],
                      style: const TextStyle(
                          fontSize: 13, color: Colors.black45)),
                  const SizedBox(height: 2),
                  Text(dt.split(' ')[1],
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black38)),
                ],
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: Colors.black26, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ConversationDetailPage extends StatefulWidget {
  final Conversation conversation;

  const ConversationDetailPage({super.key, required this.conversation});

  @override
  State<ConversationDetailPage> createState() =>
      _ConversationDetailPageState();
}

class _ConversationDetailPageState extends State<ConversationDetailPage> {
  final _service = ConversationService();
  List<ConversationMessage>? _messages;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await _service.getMessages(widget.conversation.id);
      if (mounted) setState(() => _messages = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final phone =
        widget.conversation.metadata?.callerPhoneNumber ?? 'Unknown Number';
    final name = widget.conversation.metadata?.callerName;
    return Scaffold(
      appBar: AppBar(title: Text(name ?? phone)),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(child: Text('Load failed: $_error'));
    }
    if (_messages == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages!.isEmpty) {
      return const Center(child: Text('No transcript for this call'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages!.length,
      itemBuilder: (context, i) => _MessageBubble(message: _messages![i]),
    );
  }
}

// ── 通話摘要頁（歷史紀錄用）──────────────────────────────────────────────────

class _ConversationSummaryPage extends StatefulWidget {
  final Conversation conversation;
  const _ConversationSummaryPage({required this.conversation});

  @override
  State<_ConversationSummaryPage> createState() =>
      _ConversationSummaryPageState();
}

class _ConversationSummaryPageState extends State<_ConversationSummaryPage> {
  int? _durationSecs;
  int? _finalScore;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final id = widget.conversation.id;
    final dur = prefs.getInt('call_dur_$id');

    // Fetch final score from conversation metadata via API
    int? score;
    try {
      final apiService = sl<ApiService>();
      final response = await apiService.dio.get('/api/fraud/conversations/$id');
      final data = response.data as Map<String, dynamic>?;
      final metadata = data?['metadata'] as Map<String, dynamic>?;
      final scamProb = metadata?['scam_probability'] as num?;
      if (scamProb != null) {
        score = (scamProb * 100).toInt();
      }
    } catch (e) {
      // If fetch fails, score remains null
    }

    if (mounted) {
      setState(() {
        _durationSecs = dur;
        _finalScore = score;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = widget.conversation.metadata;
    final display = meta?.callerName ?? meta?.callerPhoneNumber ?? 'Unknown Number';
    final number = meta?.callerPhoneNumber ?? '--';

    return CallSummaryPage(
      pageTitle: 'Call Summary',
      callerDisplay: display,
      callerNumber: number,
      durationSecs: _durationSecs,
      finalScore: _finalScore,
      scoreHistory: const [],
      transcript: const [],
      wasIncoming: true,
      userAnswered: false,
      onViewTranscript: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ConversationDetailPage(conversation: widget.conversation),
        ),
      ),
    );
  }
}

// ── 逐字稿泡泡頁 ──────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ConversationMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? Colors.grey.shade200 : Colors.teal.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUser ? 'Caller' : 'AI',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 2),
            Text(message.content),
          ],
        ),
      ),
    );
  }
}
