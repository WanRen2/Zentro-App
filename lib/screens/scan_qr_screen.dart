import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanQrScreen extends StatefulWidget {
  const ScanQrScreen({super.key});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final _tokenController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;
  bool _isScanning = true;
  String? _error;

  @override
  void dispose() {
    _tokenController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.isNotEmpty) {
      setState(() {
        _tokenController.text = data.text!;
        _error = null;
      });
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    setState(() {
      _isScanning = false;
      _isProcessing = true;
    });

    _processInviteCode(code);
  }

  Future<void> _processInviteCode(String code) async {
    setState(() {
      _error = null;
    });

    try {
      // Try to decode as base64
      String jsonStr;
      try {
        final decoded = base64Decode(code);
        jsonStr = utf8.decode(decoded);
      } catch (e) {
        throw Exception('Invalid invite code format');
      }

      final invite = jsonDecode(jsonStr) as Map<String, dynamic>;

      // Validate invite structure
      if (!invite.containsKey('chat_id') ||
          !invite.containsKey('sender_public_key')) {
        throw Exception('Invalid invite structure');
      }

      final chatName = invite['chat_name'] as String? ?? 'Unknown Chat';
      final senderName = invite['sender_name'] as String? ?? 'Unknown';
      final senderFingerprint = invite['sender_fingerprint'] as String? ?? '';

      if (!mounted) return;

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: const Color(0xFF1A1A1A),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF00FF9C)),
                SizedBox(width: 8),
                Text(
                  'Invite Found!',
                  style: TextStyle(color: Color(0xFF00FF9C)),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _infoRow('Chat', chatName),
                const SizedBox(height: 8),
                _infoRow('From', senderName),
                if (senderFingerprint.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _infoRow(
                    'Fingerprint',
                    '${senderFingerprint.substring(0, 8)}...',
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Full invite functionality coming soon!',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF00FF9C)),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      setState(() {
        _error = 'Invalid invite code';
      });
      // Resume scanning
      setState(() {
        _isScanning = true;
        _isProcessing = false;
      });
    }
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
        ),
      ],
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
          'Join Chat',
          style: TextStyle(color: Color(0xFFE0E0E0)),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isScanning ? Icons.keyboard : Icons.qr_code_scanner,
              color: const Color(0xFF00FF9C),
            ),
            onPressed: () {
              setState(() {
                _isScanning = !_isScanning;
                _error = null;
              });
            },
          ),
        ],
      ),
      body: _isScanning ? _buildScanner() : _buildManualInput(),
    );
  }

  Widget _buildScanner() {
    return Column(
      children: [
        // Camera view
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
                errorBuilder: (context, error, child) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.camera_alt_outlined,
                          size: 64,
                          color: Color(0xFFFF4444),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Camera error: ${error.errorCode.name}',
                          style: const TextStyle(color: Color(0xFFE0E0E0)),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Scanning overlay
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF00FF9C),
                      width: 3,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              // Scanning indicator
              if (_isProcessing)
                Container(
                  color: Colors.black54,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF00FF9C)),
                        SizedBox(height: 16),
                        Text(
                          'Processing...',
                          style: TextStyle(color: Color(0xFFE0E0E0)),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Bottom info
        Expanded(
          flex: 1,
          child: Container(
            padding: const EdgeInsets.all(24),
            color: const Color(0xFF1A1A1A),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.qr_code_scanner,
                  size: 32,
                  color: Color(0xFF00FF9C),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Point camera at QR code',
                  style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => setState(() => _isScanning = false),
                  child: const Text(
                    'Enter code manually',
                    style: TextStyle(color: Color(0xFF00FF9C)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildManualInput() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.link, size: 64, color: Color(0xFF00FF9C)),
          const SizedBox(height: 16),
          const Text(
            'Enter Invite Code',
            style: TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Paste the invite code you received',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Code input
          TextField(
            controller: _tokenController,
            style: const TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Paste invite code here...',
              hintStyle: const TextStyle(color: Color(0xFF555555)),
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste, color: Color(0xFF00FF9C)),
                onPressed: _pasteFromClipboard,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2A2A2A)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFF00FF9C),
                  width: 2,
                ),
              ),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF4444)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFFF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFFF4444),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed: _isProcessing
                ? null
                : () => _processInviteCode(_tokenController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00FF9C),
              foregroundColor: const Color(0xFF0A0A0A),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isProcessing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF0A0A0A),
                    ),
                  )
                : const Text(
                    'Join Chat',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),

          const SizedBox(height: 16),

          TextButton(
            onPressed: () => setState(() => _isScanning = true),
            child: const Text(
              'Use Camera Instead',
              style: TextStyle(color: Color(0xFF888888)),
            ),
          ),
        ],
      ),
    );
  }
}
