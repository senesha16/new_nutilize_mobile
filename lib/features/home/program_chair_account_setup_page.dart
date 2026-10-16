import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:new_nutilize_mobile/services/program_chair_account_service.dart';

class ProgramChairAccountSetupPage extends StatefulWidget {
  const ProgramChairAccountSetupPage({super.key});

  @override
  State<ProgramChairAccountSetupPage> createState() =>
      _ProgramChairAccountSetupPageState();
}

class _ProgramChairAccountSetupPageState
    extends State<ProgramChairAccountSetupPage> {
  static const _navy = Color(0xFF35489A);
  final _service = ProgramChairAccountService();
  List<ProgramChairAccount> _accounts = [];
  bool _isLoading = false;
  bool _hasProvisioned = false;
  String? _error;
  String? _provisioningWarning;
  bool _credentialsAcknowledged = false;

  Future<void> _provision() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _service.provisionAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = result.accounts;
        _provisioningWarning = result.warning;
        _hasProvisioned = true;
        _credentialsAcknowledged = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _copyCredentials() async {
    final credentials = _accounts
        .where((account) => account.temporaryPassword != null)
        .map(
          (account) =>
              '${account.program}\t${account.email}\t${account.temporaryPassword}',
        )
        .join('\n');
    if (credentials.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: credentials));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('New credentials copied. Store and share them securely.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Program Chair accounts'),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E7F3)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure account setup',
                  style: TextStyle(
                    color: Color(0xFF1C2541),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'This creates or links the 14 program-specific Program Chair accounts using NU Lipa email aliases. Dean accounts are created through the Dean registration flow. Each new Program Chair account receives a unique, randomly generated temporary password; existing Auth passwords are never reset.',
                  style: TextStyle(
                    color: Color(0xFF707891),
                    height: 1.45,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!_hasProvisioned) ...[
            const SizedBox(height: 18),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: _isLoading ? null : _provision,
              style: FilledButton.styleFrom(backgroundColor: _navy),
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(
                _isLoading ? 'Setting up accounts…' : 'Set up accounts',
              ),
            ),
          ] else ...[
            const SizedBox(height: 18),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xFFB3261E))),
              const SizedBox(height: 12),
            ],
            if (_provisioningWarning != null) ...[
              Text(
                _provisioningWarning!,
                style: const TextStyle(color: Color(0xFF8A5A00), height: 1.4),
              ),
              const SizedBox(height: 12),
            ],
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF5DC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF0D895)),
              ),
              child: const Text(
                'Save the new temporary passwords now. They are displayed only once and are not stored by this app. Do not share them in public chats.',
                style: TextStyle(
                  color: Color(0xFF684E00),
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._accounts.map(_buildAccountCard),
            if (_accounts.any((account) => account.temporaryPassword != null))
              FilledButton.icon(
                onPressed: _copyCredentials,
                style: FilledButton.styleFrom(backgroundColor: _navy),
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy new credentials'),
              ),
            CheckboxListTile(
              value: _credentialsAcknowledged,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I have saved the new credentials in a secure location.',
                style: TextStyle(fontSize: 13),
              ),
              onChanged: (checked) =>
                  setState(() => _credentialsAcknowledged = checked ?? false),
            ),
            if (_provisioningWarning != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _isLoading || !_credentialsAcknowledged
                    ? null
                    : _provision,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  _isLoading
                      ? 'Retrying…'
                      : _credentialsAcknowledged
                      ? 'Retry remaining accounts'
                      : 'Save credentials to enable retry',
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildAccountCard(ProgramChairAccount account) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E7F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            account.program,
            style: const TextStyle(
              color: Color(0xFF1C2541),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            account.email,
            style: const TextStyle(color: Color(0xFF35489A)),
          ),
          if (account.temporaryPassword != null) ...[
            const SizedBox(height: 8),
            SelectableText(
              'Temporary password: ${account.temporaryPassword}',
              style: const TextStyle(
                color: Color(0xFF39415C),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            account.created
                ? account.note
                : 'Existing account — ${account.note}',
            style: const TextStyle(color: Color(0xFF707891), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
