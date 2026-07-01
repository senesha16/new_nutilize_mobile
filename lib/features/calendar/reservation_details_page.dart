import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/features/home/home_page.dart';
import 'package:new_nutilize_mobile/features/request/request_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';

Route<T> _fadePageRoute<T>(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

class ReservationDetailsPage extends StatelessWidget {
  const ReservationDetailsPage({super.key, required this.reservation});

  final ReservationRecord reservation;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            _DetailsHeader(
              title: 'Reservation Details',
              onBack: () => Navigator.of(context).pop(),
            ),
            Container(height: 4, color: const Color(0xFFF2C94C)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ReservationSummaryCard(reservation: reservation),
                    const SizedBox(height: 14),
                    _ApprovalProcessCard(
                      currentStep: reservation.approvalState.progressIndex,
                    ),
                    const SizedBox(height: 18),
                    _ApprovalTimelineCard(reservation: reservation),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _showReportIssueFlow(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFE53935),
                              side: const BorderSide(color: Color(0xFFE53935)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              child: Text(
                                'Report an Issue',
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
                            onPressed: () => _showDownloadPermitFlow(context),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFF6A700),
                              side: const BorderSide(color: Color(0xFFF6A700)),
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
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomePage()),
                    (route) => false,
                  );
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

Future<void> _showReportIssueFlow(BuildContext context) async {
  final draft = await showDialog<_IssueReportDraft>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xD9000000),
    builder: (context) => const _ReportIssueFormDialog(),
  );

  if (draft == null) {
    return;
  }

  if (!context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xD9000000),
    builder: (context) => const _ReportIssueConfirmDialog(),
  );

  if (confirmed != true) {
    return;
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xD9000000),
    builder: (context) => const _ReportIssueSuccessDialog(),
  );
}

class _IssueReportDraft {
  const _IssueReportDraft({this.image, required this.description});

  final XFile? image;
  final String description;
}

class _ReportIssueFormDialog extends StatefulWidget {
  const _ReportIssueFormDialog();

  @override
  State<_ReportIssueFormDialog> createState() => _ReportIssueFormDialogState();
}

class _ReportIssueFormDialogState extends State<_ReportIssueFormDialog> {
  final TextEditingController _descriptionController = TextEditingController();
  XFile? _selectedImage;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final selected = await picker.pickImage(source: ImageSource.gallery);
    if (selected == null) return;
    setState(() {
      _selectedImage = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF2B300),
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'Report an Issue',
                  style: TextStyle(
                    color: Color(0xFFDA1E1E),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Image',
              style: TextStyle(
                color: Color(0xFF222222),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F1F1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8F8F8F),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Icon(
                        Icons.upload_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        _selectedImage == null
                            ? 'Upload Image'
                            : _selectedImage!.name,
                        style: const TextStyle(
                          color: Color(0xFF1F1F1F),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'JPG, PNG, up to 5mb',
                      style: TextStyle(
                        color: Color(0xFF6B6B6B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Description',
              style: TextStyle(
                color: Color(0xFF222222),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  hintText: 'Describe the issue...',
                  hintStyle: TextStyle(
                    color: Color(0xFF8A8A8A),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                style: const TextStyle(color: Color(0xFF111111), fontSize: 12),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A8A8A),
                      side: const BorderSide(color: Color(0xFFB8B8B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _IssueReportDraft(
                          image: _selectedImage,
                          description: _descriptionController.text.trim(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDA1E1E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Continue',
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
    );
  }
}

class _ReportIssueConfirmDialog extends StatelessWidget {
  const _ReportIssueConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFF2B300),
                  size: 20,
                ),
                SizedBox(width: 6),
                Text(
                  'Report an Issue',
                  style: TextStyle(
                    color: Color(0xFFDA1E1E),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text(
              'Are you sure you want to submit this report?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Our team will review your concern and contact\nyou if additional information is required.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A8A8A),
                      side: const BorderSide(color: Color(0xFFB8B8B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDA1E1E),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Continue',
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
    );
  }
}

class _ReportIssueSuccessDialog extends StatelessWidget {
  const _ReportIssueSuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Thank you for bringing this to\nour attention.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFDA1E1E),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Your report, including the attached photo,\nhas been forwarded to the appropriate office\nfor review.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 126,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDA1E1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Done',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showDownloadPermitFlow(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xD9000000),
    builder: (context) => const _DownloadPermitDialog(),
  );

  if (confirmed != true) {
    return;
  }

  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xD9000000),
    builder: (context) => const _DownloadPermitSuccessDialog(),
  );
}

class _DownloadPermitDialog extends StatelessWidget {
  const _DownloadPermitDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('🎉', style: TextStyle(fontSize: 18)),
                SizedBox(width: 6),
                Text(
                  'Download Reservation Permit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF35489A),
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Text(
              'A copy of your reservation permit will be sent to your\nregistered email address. You can print the PDF\nattachment and present it to the appropriate office if required.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8A8A8A),
                      side: const BorderSide(color: Color(0xFFB8B8B8)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF35489A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Send PDF',
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
    );
  }
}

class _DownloadPermitSuccessDialog extends StatelessWidget {
  const _DownloadPermitSuccessDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "🎉 You're All Set!",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF35489A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Your reservation permit has been sent!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Please check your Inbox or Spam folder if you do not receive it within a few minutes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF333333),
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 126,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF35489A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Done',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsHeader extends StatelessWidget {
  const _DetailsHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 72,
      color: const Color(0xFF35489A),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 12,
            child: GestureDetector(
              onTap: onBack,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
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

    return Row(
      children: List.generate(labels.length, (index) {
        final bool isCompleted = index <= currentStep;
        final bool isLast = index == labels.length - 1;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? const Color(0xFF35B556)
                            : const Color(0xFFB5B5B5),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF35B556)
                          : const Color(0xFF979797),
                      shape: BoxShape.circle,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: index < currentStep
                              ? const Color(0xFF35B556)
                              : const Color(0xFFB5B5B5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: Text(
                  labels[index],
                  textAlign: index == 0
                      ? TextAlign.left
                      : (index == 2 ? TextAlign.right : TextAlign.center),
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
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
