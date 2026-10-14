import 'dart:async';

import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/services/reservation_service.dart';

class FacultySelector extends StatefulWidget {
  const FacultySelector({
    super.key,
    required this.onChanged,
    this.selectedFaculty,
  });

  final FacultyProfile? selectedFaculty;
  final ValueChanged<FacultyProfile?> onChanged;

  @override
  State<FacultySelector> createState() => _FacultySelectorState();
}

class _FacultySelectorState extends State<FacultySelector> {
  final _reservationService = ReservationService();
  final _searchController = TextEditingController();
  Timer? _searchTimer;
  List<FacultyProfile> _results = [];
  bool _isSearching = false;
  String? _searchError;
  int _searchRevision = 0;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.selectedFaculty?.displayName ?? '';
  }

  @override
  void didUpdateWidget(covariant FacultySelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFaculty?.userId != widget.selectedFaculty?.userId &&
        widget.selectedFaculty != null) {
      _searchController.text = widget.selectedFaculty!.displayName;
      _results = [];
    }
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchTimer?.cancel();
    final revision = ++_searchRevision;
    _searchError = null;
    if (widget.selectedFaculty != null) {
      widget.onChanged(null);
    }
    if (query.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    _searchTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await _reservationService.searchActiveFaculty(query);
        if (!mounted || revision != _searchRevision) return;
        setState(() {
          _results = results;
          _isSearching = false;
        });
      } catch (error) {
        if (!mounted || revision != _searchRevision) return;
        setState(() {
          _results = [];
          _isSearching = false;
          _searchError = 'Faculty search failed: $error';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Faculty who gave permission',
          style: TextStyle(
            color: Color(0xFF111111),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search by faculty name or email',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: widget.selectedFaculty == null
                ? null
                : IconButton(
                    tooltip: 'Clear faculty selection',
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E7FB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE4E7FB)),
            ),
          ),
        ),
        if (_isSearching)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_searchError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _searchError!,
              style: const TextStyle(color: Colors.red),
            ),
          )
        else if (_searchController.text.trim().length >= 2 &&
            widget.selectedFaculty == null &&
            _results.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No active faculty found. Try another name or email.',
              style: TextStyle(color: Color(0xFF6A6F86), fontSize: 12),
            ),
          )
        else if (_results.isNotEmpty && widget.selectedFaculty == null)
          Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE4E7FB)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _results.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final faculty = _results[index];
                return ListTile(
                  dense: true,
                  title: Text(faculty.displayName),
                  subtitle: Text(faculty.email),
                  onTap: () {
                    setState(() {
                      _searchController.text = faculty.displayName;
                      _results = [];
                      _searchError = null;
                    });
                    widget.onChanged(faculty);
                  },
                );
              },
            ),
          ),
        if (widget.selectedFaculty != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Selected: ${widget.selectedFaculty!.displayName} (${widget.selectedFaculty!.email})',
              style: const TextStyle(
                color: Color(0xFF2E7D32),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}
