import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../models/chat_model.dart';
import '../models/profile_model.dart';

class InviteScreen extends StatefulWidget {
  final ChatModel chat;
  final ProfileModel profile;

  const InviteScreen({super.key, required this.chat, required this.profile});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  late String _inviteData;

  @override
  void initState() {
    super.initState();
    _generateInviteData();
  }

  void _generateInviteData() {
    final invite = {
      'v': 1,
      'chat_id': widget.chat.id,
      'chat_name': widget.chat.name,
      'sender_name': widget.profile.name,
      'ts': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'expires_at': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600,
    };
    _inviteData = base64Encode(utf8.encode(jsonEncode(invite)));
  }

  void _copyInvite() {
    Clipboard.setData(ClipboardData(text: _inviteData));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied!'),
        backgroundColor: Color(0xFF00FF9C),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _shareInvite() async {
    await Share.share(
      'Join my encrypted chat "${widget.chat.name}" on Zentro!\n\nInvite code:\n$_inviteData',
      subject: 'Zentro Chat Invite',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFE0E0E0)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Share Chat',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Chat info
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF00FF9C), width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.lock, size: 48, color: Color(0xFF00FF9C)),
                  const SizedBox(height: 12),
                  Text(
                    widget.chat.name,
                    style: const TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'End-to-End Encrypted Chat',
                    style: TextStyle(color: Color(0xFF00FF9C), fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Instructions
            const Text(
              'Share this QR code with others to join your chat',
              style: TextStyle(color: Color(0xFF888888), fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // REAL QR Code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF9C).withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Actual QR Code with invite data
                  QrImageView(
                    data: _inviteData,
                    version: QrVersions.auto,
                    size: 220.0,
                    backgroundColor: Colors.white,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    padding: const EdgeInsets.all(8),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Scan to join: ${widget.chat.name}',
                    style: const TextStyle(
                      color: Color(0xFF0A0A0A),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Invite Code (text version)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Invite Code',
                        style: TextStyle(
                          color: Color(0xFF888888),
                          fontSize: 12,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.copy,
                          color: Color(0xFF00FF9C),
                          size: 20,
                        ),
                        onPressed: _copyInvite,
                        tooltip: 'Copy code',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _inviteData,
                    style: const TextStyle(
                      color: Color(0xFF00FF9C),
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sender info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Created by',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF00FF9C),
                        child: Text(
                          widget.profile.name.isNotEmpty
                              ? widget.profile.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Color(0xFF0A0A0A),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.profile.name,
                            style: const TextStyle(
                              color: Color(0xFFE0E0E0),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'FP: ${widget.profile.fingerprint.substring(0, 8)}...',
                            style: const TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Share button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _shareInvite,
                icon: const Icon(Icons.share),
                label: const Text(
                  'Share Invite Code',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00FF9C),
                  foregroundColor: const Color(0xFF0A0A0A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info
            const Text(
              'Others can scan this QR to join your encrypted chat.\nCode expires in 1 hour.',
              style: TextStyle(color: Color(0xFF555555), fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
