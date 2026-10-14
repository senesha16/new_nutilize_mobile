import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';

class FacultyApprovalPage extends StatefulWidget {
  const FacultyApprovalPage({super.key});

  @override
  State<FacultyApprovalPage> createState() => _FacultyApprovalPageState();
}

class _FacultyApprovalPageState extends State<FacultyApprovalPage> {
  static const _navy = Color(0xFF35489A);
  static const _ink = Color(0xFF1C2541);
  static const _muted = Color(0xFF707891);
  static const _line = Color(0xFFE6EAF3);
  static const _canvas = Color(0xFFF5F7FB);

  final _reservationService = ReservationService();
  final _searchController = TextEditingController();
  List<FacultyApprovalRequest> _requests = [];
  final Set<int> _busyApprovalIds = {};
  bool _isLoading = true;
  String? _loadError;
  String _searchQuery = '';

  int? get _facultyUserId => AuthService.currentUser?['user_id'] as int?;

  List<FacultyApprovalRequest> get _visibleRequests {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _requests;
    return _requests.where((request) {
      final searchable = [
        request.activityName,
        request.requesterName,
        request.requesterEmail,
        request.roomName ?? '',
        ...request.itemSummaries,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    final facultyUserId = _facultyUserId;
    if (facultyUserId == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Your faculty profile could not be loaded. Sign in again.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final requests = await _reservationService.getFacultyApprovalRequests(
        facultyUserId: facultyUserId,
      );
      if (!mounted) return;
      setState(() {
        _requests = requests;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Unable to load student requests: $error';
      });
    }
  }

  Future<void> _approve(FacultyApprovalRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        icon: const Icon(Icons.outgoing_mail, color: _navy, size: 30),
        title: const Text('Approve this request?'),
        content: const Text(
          'The reservation will move to the next approval stage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Go back'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Approve'),
            style: FilledButton.styleFrom(backgroundColor: _navy),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _respond(request, approved: true);
    }
  }

  Future<void> _reject(FacultyApprovalRequest request) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectRequestDialog(),
    );
    if (reason != null) {
      await _respond(request, approved: false, rejectionReason: reason);
    }
  }

  Future<void> _respond(
    FacultyApprovalRequest request, {
    required bool approved,
    String? rejectionReason,
  }) async {
    setState(() => _busyApprovalIds.add(request.approvalId));
    try {
      await _reservationService.respondToFacultyApproval(
        approvalId: request.approvalId,
        approved: approved,
        rejectionReason: rejectionReason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            approved
                ? 'Approved. The request moved to the next approval stage.'
                : 'Request declined. The student can see your reason.',
          ),
        ),
      );
      await _loadRequests();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Unable to submit your response: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyApprovalIds.remove(request.approvalId));
      }
    }
  }

  String _formatDate(DateTime dateTime) =>
      MaterialLocalizations.of(context).formatMediumDate(dateTime);

  String _formatTime(DateTime dateTime) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(TimeOfDay.fromDateTime(dateTime));

  String _formatSubmittedAt(DateTime dateTime) {
    final date = _formatDate(dateTime);
    return '$date · ${_formatTime(dateTime)}';
  }

  @override
  Widget build(BuildContext context) {
    final visibleRequests = _visibleRequests;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text(
          'Student requests',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh requests',
            onPressed: _isLoading ? null : _loadRequests,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRequests,
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 260),
                  Center(child: CircularProgressIndicator(color: _navy)),
                ],
              )
            : _loadError != null
            ? _buildErrorState()
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _buildIntroCard(),
                  const SizedBox(height: 20),
                  _buildSectionHeader(visibleRequests.length),
                  const SizedBox(height: 12),
                  if (_requests.isNotEmpty) ...[
                    _buildSearchField(),
                    const SizedBox(height: 14),
                  ],
                  if (_requests.isEmpty)
                    _buildEmptyState()
                  else if (visibleRequests.isEmpty)
                    _buildNoResultsState()
                  else
                    ...visibleRequests.map(
                      (request) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildRequestCard(request),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildIntroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF35489A), Color(0xFF243574)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _navy.withAlpha(36),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(28),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.fact_check_outlined,
              color: Color(0xFFFFD66B),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review student reservations',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Check the request details before approving or declining. Approved requests continue to the school offices.',
                  style: TextStyle(
                    color: Color(0xFFE2E7FF),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(int count) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Awaiting your review',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: count == 0
                ? const Color(0xFFE9EDF5)
                : const Color(0xFFFFF2D5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count ${count == 1 ? 'request' : 'requests'}',
            style: TextStyle(
              color: count == 0 ? _muted : const Color(0xFF825900),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search by student, activity, room, or item',
        hintStyle: const TextStyle(color: _muted, fontSize: 13),
        prefixIcon: const Icon(Icons.search_rounded, color: _muted),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: _navy, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildRequestCard(FacultyApprovalRequest request) {
    final busy = _busyApprovalIds.contains(request.approvalId);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF24304C).withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE9EDFF),
                  child: Text(
                    _initials(request.requesterName),
                    style: const TextStyle(
                      color: _navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requesterName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (request.requesterEmail.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          request.requesterEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _muted, fontSize: 11),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4DA),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'PENDING',
                    style: TextStyle(
                      color: Color(0xFF825900),
                      fontSize: 9,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 17),
            Text(
              request.activityName,
              style: const TextStyle(
                color: _ink,
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _InfoLine(
                    icon: Icons.calendar_month_outlined,
                    label: 'DATE',
                    value: _formatDate(request.dateOfActivity),
                  ),
                  const SizedBox(height: 11),
                  _InfoLine(
                    icon: Icons.schedule_rounded,
                    label: 'TIME',
                    value:
                        '${_formatTime(request.startTime)} – ${_formatTime(request.endTime)}',
                  ),
                  if (request.roomName != null) ...[
                    const SizedBox(height: 11),
                    _InfoLine(
                      icon: Icons.location_on_outlined,
                      label: 'VENUE',
                      value: request.roomName!,
                    ),
                  ],
                ],
              ),
            ),
            if (request.itemSummaries.isNotEmpty ||
                request.chairsQuantity != null ||
                request.hasOutsideParticipants) ...[
              const SizedBox(height: 14),
              const Text(
                'REQUEST DETAILS',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  ...request.itemSummaries.map(
                    (summary) => _DetailChip(
                      icon: Icons.inventory_2_outlined,
                      label: summary,
                    ),
                  ),
                  if (request.chairsQuantity != null)
                    _DetailChip(
                      icon: Icons.chair_alt_outlined,
                      label: '${request.chairsQuantity} additional chairs',
                    ),
                  if (request.hasOutsideParticipants)
                    const _DetailChip(
                      icon: Icons.groups_outlined,
                      label: 'Outside participants',
                    ),
                ],
              ),
            ],
            const SizedBox(height: 13),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: _muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Submitted ${_formatSubmittedAt(request.submittedAt)}',
                    style: const TextStyle(color: _muted, fontSize: 10),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Divider(height: 1, color: _line),
            ),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : () => _reject(request),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Decline'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB3261E),
                      side: const BorderSide(color: Color(0xFFE6C9C8)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => _approve(request),
                    icon: busy
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 18),
                    label: Text(busy ? 'Submitting' : 'Approve & forward'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _navy,
                      disabledBackgroundColor: _navy.withAlpha(120),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.take(2).map((part) => part[0].toUpperCase()).join();
  }

  Widget _buildErrorState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 110),
        const _StateIcon(
          icon: Icons.cloud_off_outlined,
          color: Color(0xFFB3261E),
          background: Color(0xFFFFE9E7),
        ),
        const SizedBox(height: 16),
        const Text(
          'Requests could not be loaded',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _loadError!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _muted, height: 1.45),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: _loadRequests,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
            style: FilledButton.styleFrom(backgroundColor: _navy),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 52),
      child: Column(
        children: [
          _StateIcon(
            icon: Icons.inbox_outlined,
            color: _navy,
            background: Color(0xFFE9EDFF),
          ),
          SizedBox(height: 16),
          Text(
            'You’re all caught up',
            style: TextStyle(
              color: _ink,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'New student requests assigned to you will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return const Padding(
      padding: EdgeInsets.only(top: 38),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 42, color: _muted),
          SizedBox(height: 12),
          Text(
            'No matching requests',
            style: TextStyle(color: _ink, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 5),
          Text(
            'Try another student name, activity, room, or item.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: const Color(0xFF35489A)),
        const SizedBox(width: 9),
        SizedBox(
          width: 43,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF707891),
                fontSize: 9,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1C2541),
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF35489A)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF343C56),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateIcon extends StatelessWidget {
  const _StateIcon({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: color, size: 30),
      ),
    );
  }
}

class _RejectRequestDialog extends StatefulWidget {
  const _RejectRequestDialog();

  @override
  State<_RejectRequestDialog> createState() => _RejectRequestDialogState();
}

class _RejectRequestDialogState extends State<_RejectRequestDialog> {
  static const _line = Color(0xFFE6EAF3);
  static const _canvas = Color(0xFFF5F7FB);

  final _reasonController = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _validationMessage = 'Please provide a reason.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: const Icon(
        Icons.do_not_disturb_on_outlined,
        color: Color(0xFFB3261E),
        size: 30,
      ),
      title: const Text('Decline request'),
      content: TextField(
        controller: _reasonController,
        autofocus: true,
        maxLines: 4,
        maxLength: 500,
        onChanged: (_) {
          if (_validationMessage != null) {
            setState(() => _validationMessage = null);
          }
        },
        decoration: InputDecoration(
          labelText: 'Reason for declining',
          hintText: 'This will be shared with the student.',
          alignLabelWithHint: true,
          errorText: _validationMessage,
          filled: true,
          fillColor: _canvas,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _line),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFB3261E),
          ),
          onPressed: _submit,
          child: const Text('Decline request'),
        ),
      ],
    );
  }
}
