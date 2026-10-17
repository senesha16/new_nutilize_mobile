import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

const Color _brandBlue = Color(0xFF35489A);
const Color _brandRed = Color(0xFFE53935);

Future<T?> _showReservationDialog<T>(
  BuildContext context,
  WidgetBuilder builder,
) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: builder(dialogContext),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class ReservationDetailsPage extends StatefulWidget {
  const ReservationDetailsPage({super.key, required this.reservation});

  final ReservationRecord reservation;

  @override
  State<ReservationDetailsPage> createState() => _ReservationDetailsPageState();
}

class _ReservationDetailsPageState extends State<ReservationDetailsPage> {
  late ReservationRecord _reservation;
  final _reservationService = ReservationService();
  bool _isCancelling = false;
  bool _loadingReconsideration = false;
  bool _respondingToReconsideration = false;
  bool _refreshingAfterReconsideration = false;
  Map<String, dynamic>? _reconsideration;
  String? _reconsiderationError;
  String? _reconsiderationResponse;
  String? _reservationRefreshError;

  @override
  void initState() {
    super.initState();
    _reservation = widget.reservation;
    // If developer provided a problematic reservation id, print debug approval order
    try {
      final rid = int.tryParse(_reservation.id ?? '');
      if (rid != null && rid == 170) {
        ReservationService().printDebugApprovalOrder(rid);
      }
    } catch (_) {}
    ReservationActivityStore.listenable.addListener(_syncReservationFromStore);
    _loadRequesterReconsideration();
  }

  Future<void> _loadRequesterReconsideration() async {
    final reservationId = int.tryParse(_reservation.id ?? '');
    if (reservationId == null) return;
    setState(() {
      _loadingReconsideration = true;
      _reconsiderationError = null;
    });
    try {
      final reconsideration = await _reservationService
          .getRequesterReconsideration(reservationId);
      if (!mounted) return;
      setState(() {
        _reconsideration = reconsideration;
        _loadingReconsideration = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingReconsideration = false;
        _reconsiderationError =
            'Could not load the approval message. Please try again.';
      });
    }
  }

  Future<void> _respondToReconsideration(bool accepted) async {
    final approvalId = _reconsideration?['approval_id'] as int?;
    if (approvalId == null) {
      setState(() {
        _reconsiderationError =
            'This approval message is missing its response link. Refresh to try again.';
      });
      return;
    }
    setState(() {
      _respondingToReconsideration = true;
      _reconsiderationError = null;
    });
    try {
      await _reservationService.respondToReconsideration(
        approvalId: approvalId,
        accepted: accepted,
      );
      if (!mounted) return;
      setState(() {
        _reconsideration = null;
        _respondingToReconsideration = false;
        _reservationRefreshError = null;
        _reconsiderationResponse = accepted
            ? 'Your response was sent. The approver can now continue reviewing the request.'
            : 'You declined the requested condition. The approver can now continue reviewing the request.';
      });
      await _refreshReservationAfterReconsideration();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _respondingToReconsideration = false;
        _reconsiderationError =
            'Could not send your response. Please try again.';
      });
    }
  }

  Future<void> _refreshReservationAfterReconsideration() async {
    final userId = _reservation.userId;
    if (userId == null) {
      setState(() {
        _reservationRefreshError =
            'Your response was sent, but reservation details could not be refreshed. Reopen this page to see the latest status.';
      });
      return;
    }
    setState(() {
      _refreshingAfterReconsideration = true;
      _reservationRefreshError = null;
    });
    try {
      final records = await _reservationService.getReservationRecordsForUser(
        userId,
      );
      ReservationRecord? refreshedReservation;
      for (final record in records) {
        if (record.id == _reservation.id) {
          refreshedReservation = record;
          break;
        }
      }
      if (!mounted) return;
      if (refreshedReservation == null) {
        setState(() {
          _refreshingAfterReconsideration = false;
          _reservationRefreshError =
              'Your response was sent, but reservation details could not be refreshed. Reopen this page to see the latest status.';
        });
        return;
      }
      setState(() {
        _reservation = refreshedReservation!;
        _refreshingAfterReconsideration = false;
      });
      ReservationActivityStore.upsert(refreshedReservation);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _refreshingAfterReconsideration = false;
        _reservationRefreshError =
            'Your response was sent, but reservation details could not be refreshed. Please retry.';
      });
    }
  }

  @override
  void dispose() {
    ReservationActivityStore.listenable.removeListener(
      _syncReservationFromStore,
    );
    super.dispose();
  }

  void _syncReservationFromStore() {
    final updated = ReservationActivityStore.listenable.value;
    if (_reservation.id == null) {
      return;
    }
    final fresh = updated.firstWhere(
      (record) => record.id == _reservation.id,
      orElse: () => _reservation,
    );
    if (fresh != _reservation) {
      setState(() {
        _reservation = fresh;
      });
    }
  }

  Future<void> _handleReportIssue() async {
    final draft = await _showReservationDialog<_ReportIssueDraft>(
      context,
      (dialogContext) =>
          _ReportIssueDialog(reservedItems: _reservation.reservedItems),
    );

    if (!mounted || draft == null) {
      return;
    }

    final confirmed = await _showReservationDialog<bool>(
      context,
      (dialogContext) =>
          _ReportConfirmationDialog(draft: draft, onSubmit: _submitReport),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    await _showReservationDialog<void>(
      context,
      (dialogContext) => const _ReportSuccessDialog(),
    );
  }

  Future<void> _submitReport(_ReportIssueDraft draft) async {
    final reservationId = int.tryParse(_reservation.id ?? '');
    if (reservationId == null) {
      throw Exception('Invalid reservation id');
    }

    final imageBase64 = draft.imageBytes == null
        ? null
        : base64Encode(draft.imageBytes!);

    final success = await ReservationService().submitIssueReport(
      reservationId: reservationId,
      description: draft.description,
      imageName: draft.imageName,
      imageBase64: imageBase64,
      reportedItems: draft.reportedItems,
    );

    if (!success) {
      throw Exception('Failed to submit report');
    }
  }

  Future<void> _handleCancelRequest() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Reservation'),
          content: const Text(
            'Are you sure you want to cancel this reservation request?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes, Cancel'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isCancelling = true;
    });

    try {
      final reservationId = int.tryParse(_reservation.id ?? '');
      if (reservationId == null) {
        throw Exception('Invalid reservation id');
      }

      final success = await ReservationService().cancelReservation(
        reservationId,
      );
      if (!mounted) {
        return;
      }

      if (success) {
        final updatedTimeline = List<ReservationTimelineEntry>.from(
          _reservation.timeline,
        );
        updatedTimeline.add(
          ReservationTimelineEntry(
            title: 'Reservation Cancelled',
            status: 'Completed',
            date: DateTime.now(),
            timestamp: _formatTimestamp(DateTime.now()),
            description: 'This reservation has been cancelled.',
          ),
        );

        setState(() {
          _reservation = ReservationRecord(
            id: _reservation.id,
            userId: _reservation.userId,
            reservationTitle: _reservation.reservationTitle,
            roomName: _reservation.roomName,
            reservationType: _reservation.reservationType,
            reservationStatus: 'Cancelled',
            date: _reservation.date,
            reservationTime: _reservation.reservationTime,
            timeline: updatedTimeline,
            reservedItems: _reservation.reservedItems,
            eventVenues: _reservation.eventVenues,
            rejectionReason: _reservation.rejectionReason,
            rejectedBy: _reservation.rejectedBy,
          );
          _isCancelling = false;
        });

        ReservationActivityStore.upsert(_reservation);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation request cancelled.')),
        );
      } else {
        setState(() {
          _isCancelling = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to cancel the reservation.')),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isCancelling = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to cancel the reservation.')),
      );
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${dateTime.month}/${dateTime.day}/${dateTime.year} $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const SecondaryHeader(title: 'Reservation Details'),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReservationSummaryCard(reservation: _reservation),
                    if (_loadingReconsideration) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(minHeight: 2),
                    ],
                    if (_reconsideration != null) ...[
                      const SizedBox(height: 14),
                      _ReconsiderationResponseCard(
                        message:
                            _reconsideration!['reconsideration_message']
                                as String? ??
                            '',
                        approver: _reconsideration!['approval_stage'] == 'dean'
                            ? 'Dean'
                            : 'Program Chair',
                        responding: _respondingToReconsideration,
                        error: _reconsiderationError,
                        onRetry: _loadRequesterReconsideration,
                        onAccept: () => _respondToReconsideration(true),
                        onDecline: () => _respondToReconsideration(false),
                      ),
                    ] else if (_reconsiderationResponse != null) ...[
                      const SizedBox(height: 14),
                      _ReconsiderationResponseNotice(
                        message: _reconsiderationResponse!,
                      ),
                      if (_reservationRefreshError != null) ...[
                        const SizedBox(height: 8),
                        _ReconsiderationResponseNotice(
                          message: _reservationRefreshError!,
                          isError: true,
                          onRetry: _refreshingAfterReconsideration
                              ? null
                              : _refreshReservationAfterReconsideration,
                        ),
                      ],
                    ] else if (_reconsiderationError != null) ...[
                      const SizedBox(height: 14),
                      _ReconsiderationResponseNotice(
                        message: _reconsiderationError!,
                        isError: true,
                        onRetry: _loadRequesterReconsideration,
                      ),
                    ],
                    const SizedBox(height: 14),
                    _ApprovalProcessCard(
                      currentStep: _reservation.approvalState.progressIndex,
                      message: _reservation.approvalSummary,
                      approvalSteps: _reservation.approvalSteps,
                    ),
                    const SizedBox(height: 18),
                    _ApprovalTimelineCard(reservation: _reservation),
                    if (_reservation.reservationStatus.toLowerCase().contains(
                          'rejected',
                        ) &&
                        _reservation.rejectionReason?.isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _RejectionReasonCard(reservation: _reservation),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _handleReportIssue,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _brandRed,
                              side: const BorderSide(color: _brandRed),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Text(
                                'Report an Issue',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_reservation.reservationStatus.toLowerCase().contains(
                          'cancel',
                        ) &&
                        !_reservation.reservationStatus.toLowerCase().contains(
                          'completed',
                        ) &&
                        !_reservation.reservationStatus.toLowerCase().contains(
                          'rejected',
                        ) &&
                        !_reservation.reservationStatus.toLowerCase().contains(
                          'denied',
                        ))
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isCancelling
                              ? null
                              : _handleCancelRequest,
                          style: FilledButton.styleFrom(
                            backgroundColor: _brandRed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            child: Text(
                              _isCancelling
                                  ? 'Cancelling...'
                                  : 'Cancel Request',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNav(
        selectedIndex: AppShellScope.maybeOf(context)?.currentIndex ?? 1,
        onTap: (index) {
          final shell = AppShellScope.maybeOf(context);
          if (shell != null) {
            Navigator.of(context).pop();
            shell.onTabSelected(index);
            return;
          }

          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final currentScope = AppShellScope.maybeOf(context);
            if (currentScope != null) {
              currentScope.onTabSelected(index);
            }
          });
        },
      ),
    );
  }
}

class _ReportIssueDialog extends StatefulWidget {
  const _ReportIssueDialog({required this.reservedItems});

  final List<String> reservedItems;

  @override
  State<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReconsiderationResponseCard extends StatelessWidget {
  const _ReconsiderationResponseCard({
    required this.message,
    required this.approver,
    required this.responding,
    required this.error,
    required this.onRetry,
    required this.onAccept,
    required this.onDecline,
  });

  final String message;
  final String approver;
  final bool responding;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1D88B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                color: Color(0xFF9B6C00),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$approver requests reconsideration',
                  style: const TextStyle(
                    color: Color(0xFF26324B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message.trim().isEmpty
                ? 'Please review the requested condition and choose how to respond.'
                : message.trim(),
            style: const TextStyle(
              color: Color(0xFF3E4657),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 10),
            Text(
              error!,
              style: const TextStyle(color: Color(0xFFB3261E), fontSize: 12),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: responding ? null : onRetry,
                child: const Text('Refresh message'),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (responding)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF9E3333),
                      side: const BorderSide(color: Color(0xFFCB7770)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(backgroundColor: _brandBlue),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReconsiderationResponseNotice extends StatelessWidget {
  const _ReconsiderationResponseNotice({
    required this.message,
    this.isError = false,
    this.onRetry,
  });

  final String message;
  final bool isError;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xFFB3261E) : const Color(0xFF287447);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF2F0) : const Color(0xFFEDF7F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? const Color(0xFFF1CBC6) : const Color(0xFFCBE6D2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 19,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ReportIssueDialogState extends State<_ReportIssueDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isPickingImage = false;
  final Set<String> _selectedItems = <String>{};

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isPickingImage = true;
    });

    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (!mounted || picked == null) {
        return;
      }

      final name = picked.name.toLowerCase();
      final isAllowed =
          name.endsWith('.jpg') ||
          name.endsWith('.jpeg') ||
          name.endsWith('.png');
      if (!isAllowed) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Please select a JPG, JPEG, or PNG image.'),
          ),
        );
        return;
      }

      final fileSize = await picked.length();
      const maxSizeInBytes = 5 * 1024 * 1024;
      if (fileSize > maxSizeInBytes) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Image size must be 5 MB or smaller.')),
        );
        return;
      }

      final bytes = await picked.readAsBytes();
      if (!mounted) {
        return;
      }

      setState(() {
        _imageBytes = bytes;
        _imageName = picked.name;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to select the image right now.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _continue() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop(
      _ReportIssueDraft(
        description: _descriptionController.text.trim(),
        imageBytes: _imageBytes,
        imageName: _imageName,
        reportedItems: _selectedItems.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return _DialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Report an Issue',
                  style: TextStyle(
                    color: _brandRed,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (widget.reservedItems.isNotEmpty) ...[
                Text(
                  'Select borrowed items',
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5FB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.reservedItems.map((it) {
                      return CheckboxListTile(
                        title: Text(it, style: TextStyle(color: onSurface)),
                        value: _selectedItems.contains(it),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selectedItems.add(it);
                            } else {
                              _selectedItems.remove(it);
                            }
                          });
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                'Upload Image',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5FB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _isPickingImage
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Selecting image...',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        )
                      : _imageBytes == null
                      ? Row(
                          children: [
                            Container(
                              width: 40,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.file_upload_outlined,
                                color: Color(0xFF8A90A8),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Upload Image JPG, PNG, up to 5Mb',
                                style: TextStyle(
                                  color: Color(0xFF6A6F86),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _imageBytes!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _imageName ?? 'Selected image',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: onSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Description',
                style: TextStyle(
                  color: onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                minLines: 2,
                maxLines: 2,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Describe the issue...',
                  filled: true,
                  fillColor: const Color(0xFFF3F5FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) {
                    return 'Description is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              _DialogButtonRow(
                secondaryLabel: 'Cancel',
                primaryLabel: 'Continue',
                secondaryOnPressed: () => Navigator.of(context).pop(),
                primaryOnPressed: _continue,
                primaryColor: _brandRed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportIssueDraft {
  const _ReportIssueDraft({
    required this.description,
    required this.imageBytes,
    required this.imageName,
    this.reportedItems = const [],
  });

  final String description;
  final Uint8List? imageBytes;
  final String? imageName;
  final List<String> reportedItems;
}

class _ReportConfirmationDialog extends StatefulWidget {
  const _ReportConfirmationDialog({
    required this.draft,
    required this.onSubmit,
  });

  final _ReportIssueDraft draft;
  final Future<void> Function(_ReportIssueDraft draft) onSubmit;

  @override
  State<_ReportConfirmationDialog> createState() =>
      _ReportConfirmationDialogState();
}

class _ReportConfirmationDialogState extends State<_ReportConfirmationDialog> {
  bool _isUploading = false;

  Future<void> _submit() async {
    if (_isUploading) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      await widget.onSubmit(widget.draft);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isUploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to submit the report.'),
          action: SnackBarAction(label: 'Retry', onPressed: _submit),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return _DialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: _brandRed, size: 22),
                SizedBox(width: 6),
                Text(
                  'Report an Issue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _brandRed,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Are you sure you want to submit this report?\n\nOur team will review your concern and contact you if additional information is required.',
              textAlign: TextAlign.center,
              style: TextStyle(color: onSurface, fontSize: 13, height: 1.45),
            ),
            if (widget.draft.imageBytes != null) ...[
              const SizedBox(height: 14),
              _SelectedImagePreview(
                bytes: widget.draft.imageBytes!,
                name: widget.draft.imageName,
              ),
            ],
            const SizedBox(height: 20),
            _DialogButtonRow(
              secondaryLabel: 'Cancel',
              primaryLabel: 'Continue',
              secondaryOnPressed: _isUploading
                  ? null
                  : () => Navigator.of(context).pop(false),
              primaryOnPressed: _isUploading ? null : _submit,
              primaryColor: _brandRed,
              primaryIsBusy: _isUploading,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportSuccessDialog extends StatelessWidget {
  const _ReportSuccessDialog();

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF35B556),
              size: 34,
            ),
            const SizedBox(height: 10),
            const Text(
              'Thank you for bringing this to our attention.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _brandRed,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your report, including the attached photo, has been forwarded to the appropriate office for review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 130,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogShell extends StatelessWidget {
  const _DialogShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: 340,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DialogButtonRow extends StatelessWidget {
  const _DialogButtonRow({
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.secondaryOnPressed,
    required this.primaryOnPressed,
    required this.primaryColor,
    this.primaryIsBusy = false,
  });

  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback? secondaryOnPressed;
  final VoidCallback? primaryOnPressed;
  final Color primaryColor;
  final bool primaryIsBusy;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: secondaryOnPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF666666),
              side: const BorderSide(color: Color(0xFFBFBFBF)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: Text(
              secondaryLabel,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: primaryOnPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: primaryIsBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    primaryLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({required this.bytes, this.name});

  final Uint8List bytes;
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FB),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              bytes,
              width: 52,
              height: 52,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name ?? 'Selected image',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationSummaryCard extends StatelessWidget {
  const _ReservationSummaryCard({required this.reservation});

  final ReservationRecord reservation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF2C0), Color(0xFFD7DCF2)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Reservation In Progress',
            style: TextStyle(
              color: Color(0xFFF6B400),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            reservation.reservationTitle,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (reservation.eventVenues.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetaItem(
                  icon: Icons.calendar_month_rounded,
                  label: _formatDate(reservation.date),
                ),
                const SizedBox(height: 7),
                _MetaItem(
                  icon: Icons.access_time_rounded,
                  label: reservation.reservationTime,
                ),
                const SizedBox(height: 7),
                _MetaItem(
                  icon: Icons.meeting_room_rounded,
                  label: reservation.roomNumber,
                  maxLines: 2,
                ),
              ],
            ),
          if (reservation.eventVenues.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Venues and schedules',
              style: TextStyle(
                color: Color(0xFF35489A),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            ...reservation.eventVenues.map(_eventVenueCard),
          ] else if (reservation.reservedItems.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Borrowed Items',
              style: TextStyle(
                color: Color(0xFF6A6F86),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reservation.reservedItems.map((item) {
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0F000000),
                            blurRadius: 6,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        item,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _eventVenueCard(ReservationVenueDetail venue) {
    final removed = venue.status.toLowerCase() == 'removed';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: removed ? const Color(0xFFFFF5F3) : Colors.white,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: removed ? const Color(0xFFF0D1CC) : const Color(0xFFDDE2EF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Color(0xFF35489A),
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  venue.name,
                  style: const TextStyle(
                    color: Color(0xFF17213A),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _EventStatusBadge(removed: removed),
            ],
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(left: 25),
            child: Text(
              '${_formatDate(venue.startTime)} · ${_formatEventTime(venue.startTime)}–${_formatEventTime(venue.endTime)}',
              style: const TextStyle(
                color: Color(0xFF545F76),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
          if (venue.removalReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 25),
              child: Text(
                'Reason: ${venue.removalReason}',
                style: const TextStyle(color: Color(0xFF9A4B42), fontSize: 11),
              ),
            ),
          ],
          if (venue.equipment.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.only(left: 25),
              child: Text(
                'Borrowed for this venue',
                style: TextStyle(
                  color: Color(0xFF69758D),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 5),
            ...venue.equipment.map(_eventEquipmentRow),
          ],
        ],
      ),
    );
  }

  Widget _eventEquipmentRow(ReservationEquipmentDetail equipment) {
    final removed = equipment.status.toLowerCase() == 'removed';
    return Padding(
      padding: const EdgeInsets.only(left: 25, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                removed
                    ? Icons.remove_circle_outline
                    : Icons.inventory_2_outlined,
                size: 15,
                color: removed
                    ? const Color(0xFFB34A4A)
                    : const Color(0xFF35489A),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '${equipment.name} · Quantity ${equipment.quantity}${removed ? ' · Removed' : ''}',
                  style: TextStyle(
                    color: removed
                        ? const Color(0xFF9A4B42)
                        : const Color(0xFF17213A),
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (equipment.removalReason?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(left: 22, top: 2),
              child: Text(
                'Reason: ${equipment.removalReason}',
                style: const TextStyle(color: Color(0xFF9A4B42), fontSize: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _formatEventTime(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}

class _EventStatusBadge extends StatelessWidget {
  const _EventStatusBadge({required this.removed});

  final bool removed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: removed ? const Color(0xFFFFE5E0) : const Color(0xFFE8F5EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        removed ? 'Removed' : 'Included',
        style: TextStyle(
          color: removed ? const Color(0xFF9A4B42) : const Color(0xFF287447),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ApprovalProcessCard extends StatelessWidget {
  const _ApprovalProcessCard({
    required this.currentStep,
    required this.message,
    required this.approvalSteps,
  });

  final int currentStep;
  final String message;
  final List<String> approvalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Approval Process',
            style: TextStyle(
              color: Color(0xFF111111),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _ProcessProgressBar(currentStep: currentStep),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6A6F86)),
          ),
          if (approvalSteps.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Approval order:',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF111111),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...approvalSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '• ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6A6F86)),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6A6F86),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProcessProgressBar extends StatelessWidget {
  const _ProcessProgressBar({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final labels = ['Submitted', 'Processing', 'Approved'];

    return Column(
      children: [
        // Progress Bar
        Row(
          children: List.generate(labels.length * 2 + 1, (index) {
            // Even index = line
            if (index.isEven) {
              final lineIndex = index ~/ 2;

              bool isGreen;

              if (lineIndex == 0) {
                // Left line
                isGreen = currentStep >= 0;
              } else if (lineIndex == labels.length) {
                // Right line
                isGreen = false;
              } else {
                // Middle lines
                isGreen = currentStep >= lineIndex;
              }

              return Expanded(
                child: Container(
                  height: 3,
                  color: isGreen
                      ? const Color(0xFF35B556)
                      : const Color(0xFFB5B5B5),
                ),
              );
            }

            // Odd index = circle
            final circleIndex = index ~/ 2;

            final completed = circleIndex <= currentStep;

            return Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFF35B556)
                    : const Color(0xFF9E9E9E),
                shape: BoxShape.circle,
              ),
              child: completed
                  ? const Icon(Icons.check, size: 12, color: Colors.white)
                  : null,
            );
          }),
        ),

        const SizedBox(height: 10),

        // Labels
        Row(
          children: labels.map((label) {
            return Expanded(
              child: Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ApprovalTimelineCard extends StatelessWidget {
  const _ApprovalTimelineCard({required this.reservation});

  final ReservationRecord reservation;

  @override
  Widget build(BuildContext context) {
    final entries = reservation.approvalTimeline;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: entries
            .asMap()
            .entries
            .map(
              (entry) => _TimelineRow(
                entry: entry.value,
                isLast: entry.key == entries.length - 1,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _RejectionReasonCard extends StatelessWidget {
  const _RejectionReasonCard({required this.reservation});

  final ReservationRecord reservation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rejection Reason',
            style: TextStyle(
              color: Color(0xFFC62828),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (reservation.rejectedBy?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              'Rejected by: ${reservation.rejectedBy}',
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            reservation.rejectionReason!,
            style: const TextStyle(
              color: Color(0xFF4A4A4A),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.entry, required this.isLast});

  final ReservationTimelineEntry entry;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final bool completed = entry.isCompleted;
    final Color indicatorColor = completed
        ? const Color(0xFF35B556)
        : const Color(0xFF9E9E9E);
    final Color lineColor = completed
        ? const Color(0xFF35B556)
        : const Color(0xFF9E9E9E);
    final Color titleColor = completed
        ? const Color(0xFF111111)
        : const Color(0xFFB1B1B1);
    final Color bodyColor = completed
        ? const Color(0xFF6A6F86)
        : const Color(0xFFBFBFBF);

    // Use approval time if available (from backend), otherwise use timestamp
    final displayTime = entry.approvalTimeFormatted.isNotEmpty
        ? entry.approvalTimeFormatted
        : entry.timestamp;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayTime,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: completed
                      ? const Color(0xFF111111)
                      : const Color(0xFFB1B1B1),
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: indicatorColor,
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast) Container(width: 2, height: 34, color: lineColor),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  entry.description,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label, this.maxLines = 1});

  final IconData icon;
  final String label;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        children: [
          Icon(icon, size: 15, color: const Color(0xFF111111)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              label,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF111111), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${monthNames[date.month - 1]} ${date.day}, ${date.year}';
}
