import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/secondary_header.dart';

const Color _brandBlue = Color(0xFF35489A);
const Color _brandRed = Color(0xFFE53935);
const Color _brandAmber = Color(0xFFF6A700);

Route<T> _fadePageRoute<T>(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

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
  Future<void> _handleDownloadPermit() async {
    final sent = await _showReservationDialog<bool>(
      context,
      (dialogContext) => _DownloadPermitDialog(
        reservation: widget.reservation,
        onSendPdf: _sendPermitPdf,
      ),
    );

    if (!mounted || sent != true) {
      return;
    }

    await _showReservationDialog<void>(
      context,
      (dialogContext) => const _PermitSuccessDialog(),
    );
  }

  Future<void> _handleReportIssue() async {
    final draft = await _showReservationDialog<_ReportIssueDraft>(
      context,
      (dialogContext) => const _ReportIssueDialog(),
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

  Future<void> _sendPermitPdf(ReservationRecord reservation) async {
    await Future<void>.delayed(const Duration(seconds: 2));
  }

  Future<void> _submitReport(_ReportIssueDraft draft) async {
    await Future<void>.delayed(const Duration(seconds: 2));
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
                    _ReservationSummaryCard(reservation: widget.reservation),
                    const SizedBox(height: 14),
                    _ApprovalProcessCard(
                      currentStep:
                          widget.reservation.approvalState.progressIndex,
                    ),
                    const SizedBox(height: 18),
                    _ApprovalTimelineCard(reservation: widget.reservation),
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
                        const SizedBox(width: 14),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _handleDownloadPermit,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _brandAmber,
                              side: const BorderSide(color: _brandAmber),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Text(
                                'Print / Download',
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
                  ],
                ),
              ),
            ),
            AppBottomNav(
              selectedIndex: 1,
              onTap: (index) {
                if (index == 0) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (index == 1) {
                  Navigator.of(context).pop();
                } else if (index == 2) {
                  Navigator.of(
                    context,
                  ).push(_fadePageRoute(const RequestPage()));
                } else if (index == 3) {
                  Navigator.of(context).push(_fadePageRoute(const UserPage()));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadPermitDialog extends StatefulWidget {
  const _DownloadPermitDialog({
    required this.reservation,
    required this.onSendPdf,
  });

  final ReservationRecord reservation;
  final Future<void> Function(ReservationRecord reservation) onSendPdf;

  @override
  State<_DownloadPermitDialog> createState() => _DownloadPermitDialogState();
}

class _DownloadPermitDialogState extends State<_DownloadPermitDialog> {
  bool _isSending = false;

  Future<void> _sendPdf() async {
    if (_isSending) {
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.onSendPdf(widget.reservation);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to send the reservation permit.'),
          action: SnackBarAction(label: 'Retry', onPressed: _sendPdf),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return _DialogShell(
      child: Padding(
        padding: EdgeInsets.fromLTRB(22, 20, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Download Reservation Permit',
              style: TextStyle(
                color: _brandBlue,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'A copy of your reservation permit will be sent to your registered email address. You can print the PDF attachment and present it to the appropriate office if required.',
              style: TextStyle(color: onSurface, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 22),
            _DialogButtonRow(
              secondaryLabel: 'Cancel',
              primaryLabel: 'Send PDF',
              secondaryOnPressed: _isSending
                  ? null
                  : () => Navigator.of(context).pop(false),
              primaryOnPressed: _isSending ? null : _sendPdf,
              primaryColor: _brandBlue,
              primaryIsBusy: _isSending,
            ),
          ],
        ),
      ),
    );
  }
}

class _PermitSuccessDialog extends StatelessWidget {
  const _PermitSuccessDialog();

  @override
  Widget build(BuildContext context) {
    return _DialogShell(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 10),
            const Text(
              "You're All Set!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _brandBlue,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Your reservation permit has been sent to your registered email.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Please check your Inbox or Spam folder if you do not receive it within a few minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: 130,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandBlue,
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

class _ReportIssueDialog extends StatefulWidget {
  const _ReportIssueDialog();

  @override
  State<_ReportIssueDialog> createState() => _ReportIssueDialogState();
}

class _ReportIssueDialogState extends State<_ReportIssueDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isPickingImage = false;

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
  });

  final String description;
  final Uint8List? imageBytes;
  final String? imageName;
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
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaItem(
                icon: Icons.calendar_month_rounded,
                label: _formatDate(reservation.date),
              ),
              const _MetaSeparator(),
              _MetaItem(
                icon: Icons.access_time_rounded,
                label: reservation.reservationTime,
              ),
              const _MetaSeparator(),
              _MetaItem(
                icon: Icons.meeting_room_rounded,
                label: reservation.roomNumber,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApprovalProcessCard extends StatelessWidget {
  const _ApprovalProcessCard({required this.currentStep});

  final int currentStep;

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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 54,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                entry.timestamp,
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
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF111111)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _MetaSeparator extends StatelessWidget {
  const _MetaSeparator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        '|',
        style: TextStyle(
          color: Color(0xFF111111),
          fontSize: 11,
          fontWeight: FontWeight.w400,
        ),
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
