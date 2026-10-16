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
  bool get _isProgramChair {
    return AuthService.programIdForProgramChairRole(
          AuthService.currentUser?['role']?.toString(),
        ) !=
        null;
  }

  bool get _isDean =>
      (AuthService.currentUser?['role']?.toString().toLowerCase() ?? '') ==
          'dean' ||
      AuthService.isDeanRole(AuthService.currentUser?['role']?.toString());

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
    final currentUser = AuthService.currentUser;
    final facultyUserId = _facultyUserId;
    final programId = int.tryParse(
      currentUser?['program_id']?.toString() ?? '',
    );
    final officeId = int.tryParse(currentUser?['office_id']?.toString() ?? '');
    if (facultyUserId == null ||
        (_isProgramChair && programId == null) ||
        (_isDean && officeId == null)) {
      setState(() {
        _isLoading = false;
        _loadError = _isProgramChair || _isDean
            ? 'Your approval assignment could not be loaded. Sign in again or contact an administrator.'
            : 'Your faculty profile could not be loaded. Sign in again.';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final requests = _isProgramChair
          ? await _reservationService.getProgramChairApprovalRequests(
              officeId: await _reservationService.getProgramOfficeId(
                programId!,
              ),
            )
          : _isDean
          ? await _reservationService.getDeanApprovalRequests(
              officeId: officeId!,
            )
          : await _reservationService.getFacultyApprovalRequests(
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
        _loadError = 'Unable to load approval requests: $error';
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

  Future<void> _reconsider(FacultyApprovalRequest request) async {
    final message = await showDialog<String>(
      context: context,
      builder: (_) => const _ReconsiderRequestDialog(),
    );
    if (message != null) {
      await _respond(request, decision: 'reconsider', message: message);
    }
  }

  Future<void> _respond(
    FacultyApprovalRequest request, {
    bool? approved,
    String? decision,
    String? message,
    String? rejectionReason,
  }) async {
    setState(() => _busyApprovalIds.add(request.approvalId));
    try {
      if (_isProgramChair) {
        await _reservationService.respondToProgramChairApproval(
          approvalId: request.approvalId,
          decision: decision ?? (approved == true ? 'approve' : 'reject'),
          message: message,
          rejectionReason: rejectionReason,
        );
      } else if (_isDean) {
        await _reservationService.respondToDeanApproval(
          approvalId: request.approvalId,
          decision: decision ?? (approved == true ? 'approve' : 'reject'),
          message: message,
          rejectionReason: rejectionReason,
        );
      } else {
        await _reservationService.respondToFacultyApproval(
          approvalId: request.approvalId,
          approved: approved == true,
          rejectionReason: rejectionReason,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            decision == 'reconsider'
                ? 'Condition sent to the requester. The request will return to you after their response.'
                : approved == true
                ? 'Approved. The request moved to the next approval stage.'
                : 'Request declined. The requester can see your reason.',
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
        title: Text(
          _isProgramChair
              ? 'Program requests'
              : _isDean
              ? 'Dean approvals'
              : 'Student requests',
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDean
                      ? 'Review Dean approvals'
                      : _isProgramChair
                      ? 'Review program reservations'
                      : 'Review student reservations',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isDean
                      ? 'Review requests sent to the Dean office and approve them to continue to the next school office.'
                      : _isProgramChair
                      ? 'Review requests from your assigned program. Approve, decline with a reason, or ask the requester to consider a condition.'
                      : 'Check the request details before approving or declining. Approved requests continue to the school offices.',
                  style: const TextStyle(
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
        hintText: 'Search by requester, activity, room, or item',
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
    final normalizedStatus = request.status.toLowerCase();
    final isAwaitingFinalDecision =
        normalizedStatus == 'condition accepted' ||
        normalizedStatus == 'condition rejected';
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
                  child: Text(
                    request.status.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF825900),
                      fontSize: 9,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            if ((_isProgramChair || _isDean) && isAwaitingFinalDecision) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF3FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD9E1FF)),
                ),
                child: Text(
                  normalizedStatus == 'condition accepted'
                      ? 'The requester accepted your condition. Make the final approval decision.'
                      : 'The requester declined your condition. Make the final approval decision.',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
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
            if ((_isProgramChair || _isDean) && !isAwaitingFinalDecision) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _reject(request),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text('Decline'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFB3261E),
                        side: const BorderSide(color: Color(0xFFE6C9C8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _reconsider(request),
                      icon: const Icon(Icons.chat_bubble_outline, size: 17),
                      label: const Text('Reconsider'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: _line),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : () => _approve(request),
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Approve'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
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
                      label: Text(
                        busy
                            ? 'Submitting'
                            : _isProgramChair ||
                                  _isDean ||
                                  isAwaitingFinalDecision
                            ? 'Final approve'
                            : 'Approve & forward',
                      ),
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
            'New requests assigned to you will appear here.',
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

class _ReconsiderRequestDialog extends StatefulWidget {
  const _ReconsiderRequestDialog();

  @override
  State<_ReconsiderRequestDialog> createState() =>
      _ReconsiderRequestDialogState();
}

class _ReconsiderRequestDialogState extends State<_ReconsiderRequestDialog> {
  final _messageController = TextEditingController();
  String? _validationMessage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      setState(
        () => _validationMessage = 'Enter the condition for the requester.',
      );
      return;
    }
    if (message.length > 1000) {
      setState(
        () => _validationMessage =
            'The message must be 1,000 characters or fewer.',
      );
      return;
    }
    Navigator.of(context).pop(message);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      icon: const Icon(
        Icons.chat_bubble_outline,
        color: Color(0xFF35489A),
        size: 30,
      ),
      title: const Text('Ask the requester to reconsider'),
      content: TextField(
        controller: _messageController,
        autofocus: true,
        maxLines: 5,
        maxLength: 1000,
        onChanged: (_) {
          if (_validationMessage != null) {
            setState(() => _validationMessage = null);
          }
        },
        decoration: InputDecoration(
          labelText: 'Condition or alternative',
          hintText: 'Explain what could make this request workable.',
          alignLabelWithHint: true,
          errorText: _validationMessage,
          filled: true,
          fillColor: const Color(0xFFF5F7FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE6EAF3)),
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
            backgroundColor: const Color(0xFF35489A),
          ),
          onPressed: _submit,
          child: const Text('Send condition'),
        ),
      ],
    );
  }
}
