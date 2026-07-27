import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';

class ItemReservationPage extends StatefulWidget {
  const ItemReservationPage({super.key});

  @override
  State<ItemReservationPage> createState() => _ItemReservationPageState();
}

class _ItemReservationPageState extends State<ItemReservationPage> {
  final _reservationService = ReservationService();
  final _activityController = TextEditingController();

  int _currentStep = 1;
  DateTime? _selectedDate;
  TimeOfDay? _selectedStartTime;
  TimeOfDay? _selectedEndTime;
  File? _proofOfConsentFile;
  String? _proofOfConsentUrl;
  bool _isUploadingProof = false;
  bool _agreedToTerms = false;

  List<ItemModel> _allItems = [];
  Map<int, int> _selectedItemQuantities = {}; // item_id -> quantity
  bool _isLoadingItems = false;
  bool _isLoadingStep2 = false;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  @override
  void dispose() {
    _activityController.dispose();
    super.dispose();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoadingItems = true);
    final items = await _reservationService.getAllItems();
    if (mounted) {
      setState(() {
        _allItems = items;
        _isLoadingItems = false;
      });
    }
  }

  Future<void> _pickProofOfConsent() async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() => _proofOfConsentFile = File(pickedFile.path));
        await _uploadProofOfConsent();
      }
    } catch (e) {
      _showError('Error picking image: $e');
    }
  }

  Future<void> _uploadProofOfConsent() async {
    if (_proofOfConsentFile == null) {
      _showError('No file selected');
      return;
    }

    setState(() => _isUploadingProof = true);

    try {
      final user = AuthService.currentUser;
      final userId = user?['user_id'].toString();
      if (userId == null) {
        _showError('User not authenticated');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'item_proof_${timestamp}.jpg';
      final filePath = 'proof_of_consent/$userId/$fileName';

      await _reservationService.uploadProofOfConsent(_proofOfConsentFile!, filePath);
      final publicUrl = _reservationService.getProofOfConsentUrl(filePath);

      setState(() {
        _proofOfConsentUrl = publicUrl;
        _isUploadingProof = false;
      });
      _showError('Proof of consent uploaded successfully!');
    } catch (e) {
      setState(() => _isUploadingProof = false);
      _showError('Error uploading proof of consent: $e');
    }
  }

  void _startDatePicker() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today,
      lastDate: DateTime(today.year + 1),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: const Color(0xFF35489A),
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showTimePicker({required bool isStart}) async {
    final initial = isStart
        ? _selectedStartTime ?? const TimeOfDay(hour: 8, minute: 0)
        : _selectedEndTime ?? const TimeOfDay(hour: 10, minute: 0);

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          timePickerTheme: const TimePickerThemeData(
            dialBackgroundColor: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _selectedStartTime = picked;
          if (_selectedEndTime != null && _isBeforeOrEqual(_selectedEndTime!, picked)) {
            _selectedEndTime = null;
          }
        } else {
          _selectedEndTime = picked;
        }
      });
    }
  }

  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(4, (index) {
        final active = index < _currentStep;
        return Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFF6C914) : const Color(0xFFD9DCE8),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }

  Widget _buildStepHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $_currentStep out of 4',
          style: const TextStyle(color: Color(0xFF35489A), fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        _buildProgressIndicator(),
      ],
    );
  }

  bool _isBeforeOrEqual(TimeOfDay a, TimeOfDay b) {
    return a.hour < b.hour || (a.hour == b.hour && a.minute <= b.minute);
  }

  String _timeLabel(TimeOfDay? time) {
    if (time == null) return 'Select';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _goToNextStep() {
    if (_currentStep == 1) {
      if (_activityController.text.isEmpty) {
        _showError('Enter activity name');
        return;
      }
      if (_selectedDate == null) {
        _showError('Select date');
        return;
      }
      if (_selectedStartTime == null || _selectedEndTime == null) {
        _showError('Select time range');
        return;
      }
      if (_isBeforeOrEqual(_selectedEndTime!, _selectedStartTime!)) {
        _showError('End time must be after start time');
        return;
      }
      final user = AuthService.currentUser;
      final role = user?['role'] as String?;
      final isStudent = role?.toLowerCase() == 'student';
      if (isStudent && _proofOfConsentUrl == null) {
        _showError('Please upload proof of consent');
        return;
      }
      setState(() => _currentStep = 2);
      return;
    }

    if (_currentStep == 2) {
      if (_selectedItemQuantities.isEmpty) {
        _showError('Select at least one item');
        return;
      }
      setState(() => _currentStep = 3);
      return;
    }

    if (_currentStep == 3) {
      setState(() => _currentStep = 4);
      return;
    }
  }

  void _goToPreviousStep() {
    if (_currentStep == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _currentStep -= 1);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submitReservation() async {
    if (!_agreedToTerms) {
      _showError('Please agree to terms and conditions');
      return;
    }

    final currentUser = AuthService.currentUser;
    if (currentUser == null) {
      _showError('Please sign in again');
      return;
    }

    final startDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedStartTime!.hour,
      _selectedStartTime!.minute,
    );
    final endDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedEndTime!.hour,
      _selectedEndTime!.minute,
    );

    try {
      // Create item reservation in database
      final reservationId = await _reservationService.createItemReservation(
        activityName: _activityController.text.trim(),
        userId: currentUser['user_id'] as int,
        dateOfActivity: _selectedDate!,
        startTime: startDateTime,
        endTime: endDateTime,
        itemQuantities: _selectedItemQuantities,
        proofOfConsentUrl: _proofOfConsentUrl,
      );

      if (reservationId != null) {
        _showError('Item reservation submitted successfully!');
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.of(context).pop();
        });
      }
    } catch (e) {
      _showError('Error submitting reservation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (_currentStep > 1) {
          _goToPreviousStep();
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F5FB),
        body: SafeArea(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 92,
                decoration: const BoxDecoration(
                  color: Color(0xFF35489A),
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFF2C94C), width: 4),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _currentStep == 1 ? () => Navigator.of(context).pop() : _goToPreviousStep,
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    Text(
                      'Item Reservation - $_currentStep/4',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStepHeader(),
                      const SizedBox(height: 18),
                      if (_currentStep == 1)
                        _buildStepOne()
                      else if (_currentStep == 2)
                        _buildStepTwo()
                      else if (_currentStep == 3)
                        _buildStepThree()
                      else
                        _buildStepFour(),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _goToPreviousStep,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF6C914), width: 2),
                          ),
                          child: const Center(
                            child: Text(
                              'Previous',
                              style: TextStyle(
                                color: Color(0xFFF6C914),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _currentStep == 4 ? _submitReservation : _goToNextStep,
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFF35489A),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              _currentStep == 4 ? 'Submit' : 'Next',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepOne() {
    final user = AuthService.currentUser;
    final role = user?['role'] as String?;
    final isStudent = role?.toLowerCase() == 'student';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormCard(children: [
          _buildInputField('Activity Name', _activityController, 'Enter activity name'),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Date', style: TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          _buildDateBox(),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Time Range', style: TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTimeBox('From', _selectedStartTime, () => _showTimePicker(isStart: true))),
              const SizedBox(width: 12),
              Expanded(child: _buildTimeBox('To', _selectedEndTime, () => _showTimePicker(isStart: false))),
            ],
          ),
          if (isStudent) ...[
            const SizedBox(height: 16),
            _buildProofOfConsentUpload(),
          ],
        ]),
      ],
    );
  }

  Widget _buildStepTwo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Items to Borrow',
          style: TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 16),
        if (_isLoadingItems)
          const Center(child: CircularProgressIndicator())
        else if (_allItems.isEmpty)
          const Center(child: Text('No items available'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _allItems.length,
            itemBuilder: (context, index) {
              final item = _allItems[index];
              final selectedQty = _selectedItemQuantities[item.itemId] ?? 0;
              final remaining = item.quantityTotal - item.quantityInUse;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selectedQty > 0 ? const Color(0xFFF6C914) : const Color(0xFFE4E7FB),
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.itemName,
                                style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Available: $remaining / ${item.quantityTotal}',
                                style: const TextStyle(
                                  color: Color(0xFF6A6F86),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (remaining > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E9D50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Available',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD22828),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Out of Stock',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (remaining > 0) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: selectedQty > 0
                                ? () {
                                    setState(() {
                                      _selectedItemQuantities[item.itemId] = selectedQty - 1;
                                      if (_selectedItemQuantities[item.itemId] == 0) {
                                        _selectedItemQuantities.remove(item.itemId);
                                      }
                                    });
                                  }
                                : null,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selectedQty > 0
                                    ? const Color(0xFFF6C914)
                                    : const Color(0xFFE4E7FB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.remove, color: Colors.white, size: 18),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            selectedQty.toString(),
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: selectedQty < remaining
                                ? () {
                                    setState(() {
                                      _selectedItemQuantities[item.itemId] = selectedQty + 1;
                                    });
                                  }
                                : null,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: selectedQty < remaining
                                    ? const Color(0xFF35489A)
                                    : const Color(0xFFE4E7FB),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.add, color: Colors.white, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStepThree() {
    final selectedItems = _allItems.where((item) => _selectedItemQuantities.containsKey(item.itemId)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormCard(children: [
          const Text(
            'Review Your Request',
            style: TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          _buildReviewSection('Activity Details', [
            ('Activity Name', _activityController.text),
            ('Date', '${_selectedDate?.month}/${_selectedDate?.day}/${_selectedDate?.year}'),
            ('Time', '${_timeLabel(_selectedStartTime)} - ${_timeLabel(_selectedEndTime)}'),
          ]),
          const SizedBox(height: 20),
          _buildReviewSection('Items', [
            for (final item in selectedItems) ('${item.itemName}', '${_selectedItemQuantities[item.itemId]} unit(s)'),
          ]),
        ]),
      ],
    );
  }

  Widget _buildStepFour() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormCard(children: [
          const Text(
            'Terms and Conditions',
            style: TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5FB),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E7FB), width: 1),
            ),
            child: SingleChildScrollView(
              child: Text(
                '''By submitting this item reservation request, you acknowledge and agree to the following:

1. You are responsible for the safekeeping of all borrowed items.
2. Items must be returned in the same condition as borrowed.
3. Any damage or loss must be reported immediately.
4. Late returns may result in penalties as per institutional policy.
5. The institution reserves the right to deny future reservations for violation of terms.
6. You agree to follow all posted rules and regulations regarding borrowed items.''',
                style: const TextStyle(
                  color: Color(0xFF6A6F86),
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _agreedToTerms ? const Color(0xFF35489A) : Colors.white,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _agreedToTerms ? const Color(0xFF35489A) : const Color(0xFFB0B6D7),
                      width: 2,
                    ),
                  ),
                  child: _agreedToTerms
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'I agree to the terms and conditions',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ]),
      ],
    );
  }

  Widget _buildFormCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 26, offset: Offset(0, 10))],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFB0B6D7), fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF6C914), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFF6C914), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF35489A), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateBox() {
    return GestureDetector(
      onTap: _startDatePicker,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF6C914), width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedDate == null ? 'MM / DD / YYYY' : '${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}',
                style: TextStyle(
                  color: _selectedDate == null ? const Color(0xFFB0B6D7) : const Color(0xFF111111),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, color: Color(0xFF35489A)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(String label, TimeOfDay? value, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF6C914), width: 2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value == null ? 'Select' : _timeLabel(value),
                style: TextStyle(
                  color: value == null ? const Color(0xFFB0B6D7) : const Color(0xFF111111),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.watch_later_outlined, color: Color(0xFF35489A)),
          ],
        ),
      ),
    );
  }

  Widget _buildProofOfConsentUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attach Your Proof of Consent',
          style: TextStyle(color: Color(0xFF111111), fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        if (_proofOfConsentFile != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E9D50), width: 2),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF2E9D50), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('File Selected', style: TextStyle(color: Color(0xFF2E9D50), fontSize: 12, fontWeight: FontWeight.w700)),
                      Text(_proofOfConsentFile!.path.split('/').last, style: const TextStyle(color: Color(0xFF2E9D50), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isUploadingProof ? null : _pickProofOfConsent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD79700), width: 1),
              ),
              child: Center(
                child: Text(_isUploadingProof ? 'Uploading...' : 'Change Photo', style: const TextStyle(color: Color(0xFFD79700), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ] else ...[
          GestureDetector(
            onTap: _isUploadingProof ? null : _pickProofOfConsent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF6C914), width: 2),
              ),
              child: Column(
                children: [
                  Icon(
                    _isUploadingProof ? Icons.hourglass_top : Icons.image_outlined,
                    color: const Color(0xFFF6C914),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isUploadingProof ? 'Uploading...' : 'Tap to Upload Photo',
                    style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text('Choose from gallery', style: TextStyle(color: Color(0xFFB0B6D7), fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReviewSection(String title, List<(String, String)> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Color(0xFF111111), fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        for (final (label, value) in items) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Color(0xFF6A6F86), fontSize: 12)),
              Text(value, style: const TextStyle(color: Color(0xFF111111), fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
