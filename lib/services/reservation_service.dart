import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:new_nutilize_mobile/features/calendar/reservation_data.dart';
import 'package:new_nutilize_mobile/services/auth_service.dart';
import 'package:new_nutilize_mobile/services/supabase_service.dart';

/// Visible name for an approval office. The stored office stays unchanged.
String approvalOfficeLabel(String officeName) {
  if (officeName.trim().toLowerCase() == 'do') return 'Safety';
  return officeName;
}

// MARK: - Models

class Room {
  final int roomId;
  final String roomNumber;
  final String roomType; // Classroom, Gym, AVR, Lobby, Student Lounge
  final String?
  roomTableType; // For classrooms: arm chair, trapezoidal, accounting table
  final int? roomCapacity;
  final int? roomChairQuantity;
  final int? roomTableCount;
  final bool maintenanceStatus;
  final bool availabilityStatus;

  Room({
    required this.roomId,
    required this.roomNumber,
    required this.roomType,
    this.roomTableType,
    this.roomCapacity,
    this.roomChairQuantity,
    this.roomTableCount,
    required this.maintenanceStatus,
    required this.availabilityStatus,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      roomId: json['room_id'] as int,
      roomNumber: json['room_number'] as String,
      roomType: json['room_type'] as String,
      roomTableType: json['room_table_type'] as String?,
      roomCapacity: json['room_capacity'] as int?,
      roomChairQuantity: json['room_chair_quantity'] as int?,
      roomTableCount: json['room_table_count'] as int?,
      maintenanceStatus: json['maintenance_status'] as bool? ?? false,
      availabilityStatus: json['availability_status'] as bool? ?? true,
    );
  }
}

class ItemModel {
  final int itemId;
  final String itemName;
  final int quantityTotal;
  final int quantityInUse;
  final int? ownerId;
  final String? ownerName;
  final bool maintenanceStatus;
  final bool availabilityStatus;

  static int normalizeItemUsage(int total, int usage) {
    final safeTotal = total < 0 ? 0 : total;
    return usage.clamp(0, safeTotal);
  }

  static int normalizeAvailableQuantity(int total, int usage) {
    final safeTotal = total < 0 ? 0 : total;
    return (safeTotal - usage).clamp(0, safeTotal);
  }

  int get availableQuantity =>
      normalizeAvailableQuantity(quantityTotal, quantityInUse);

  ItemModel({
    required this.itemId,
    required this.itemName,
    required this.quantityTotal,
    required this.quantityInUse,
    this.ownerId,
    this.ownerName,
    required this.maintenanceStatus,
    required this.availabilityStatus,
  });

  factory ItemModel.fromJson(Map<String, dynamic> json) {
    return ItemModel(
      itemId: json['item_id'] as int,
      itemName: json['item_name'] as String,
      quantityTotal: json['quantity_total'] as int? ?? 0,
      quantityInUse: json['quantity_in_use'] as int? ?? 0,
      ownerId: json['owner_id'] as int?,
      ownerName: json['item_owners']?['owner_name'] as String?,
      maintenanceStatus: json['maintenance_status'] as bool? ?? false,
      availabilityStatus: json['availability_status'] as bool? ?? true,
    );
  }
}

class ReservationSlot {
  final DateTime startTime;
  final DateTime endTime;
  final int roomId;
  final int reservationId;
  final String status;

  ReservationSlot({
    required this.startTime,
    required this.endTime,
    required this.roomId,
    required this.reservationId,
    required this.status,
  });
}

class ApprovalChain {
  final List<String> offices; // List of office names in approval order
  final List<int> officeIds;

  ApprovalChain({required this.offices, required this.officeIds});
}

class _RequesterApprovalRouting {
  const _RequesterApprovalRouting({
    required this.isProgramChair,
    required this.isDean,
    required this.programChairOfficeId,
    required this.deanOfficeId,
  });

  final bool isProgramChair;
  final bool isDean;
  final int? programChairOfficeId;
  final int? deanOfficeId;
}

class FacultyProfile {
  const FacultyProfile({
    required this.userId,
    required this.displayName,
    required this.email,
  });

  final int userId;
  final String displayName;
  final String email;

  factory FacultyProfile.fromJson(Map<String, dynamic> json) {
    return FacultyProfile(
      userId: json['user_id'] as int,
      displayName: json['display_name'] as String,
      email: json['email'] as String,
    );
  }
}

class FacultyApprovalRequest {
  const FacultyApprovalRequest({
    required this.approvalId,
    required this.reservationId,
    required this.activityName,
    required this.requesterName,
    required this.requesterEmail,
    required this.dateOfActivity,
    required this.startTime,
    required this.endTime,
    required this.submittedAt,
    required this.hasOutsideParticipants,
    required this.itemSummaries,
    this.chairsQuantity,
    this.roomName,
    this.status = 'Pending',
    this.reconsiderationMessage,
    this.institutionalEventResources = const [],
  });

  final int approvalId;
  final int reservationId;
  final String activityName;
  final String requesterName;
  final String requesterEmail;
  final DateTime dateOfActivity;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime submittedAt;
  final bool hasOutsideParticipants;
  final List<String> itemSummaries;
  final int? chairsQuantity;
  final String? roomName;
  final String status;
  final String? reconsiderationMessage;
  final List<InstitutionalEventResource> institutionalEventResources;
  bool get isInstitutionalEvent => institutionalEventResources.isNotEmpty;
}

class InstitutionalEventVenueSchedule {
  const InstitutionalEventVenueSchedule({
    required this.roomId,
    required this.startTime,
    required this.endTime,
  });

  final int roomId;
  final DateTime startTime;
  final DateTime endTime;
}

class InstitutionalEventEquipmentRequest {
  const InstitutionalEventEquipmentRequest({
    required this.itemId,
    required this.quantity,
    required this.venueIndex,
  });

  final int itemId;
  final int quantity;
  final int venueIndex;
}

class InstitutionalEventResource {
  const InstitutionalEventResource({
    required this.id,
    required this.kind,
    required this.name,
    required this.status,
    this.startTime,
    this.endTime,
    this.scheduleLabel,
    this.quantity,
    this.venueName,
    this.removalReason,
  });

  final int id;
  final String kind;
  final String name;
  final String status;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? scheduleLabel;
  final int? quantity;
  final String? venueName;
  final String? removalReason;

  String get label => kind == 'venue'
      ? name
      : '$name${quantity == null ? '' : ' (quantity: $quantity)'}';
}

bool _isUnitAvailableStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  return normalized == 'available' ||
      normalized == 'free' ||
      normalized == 'ready' ||
      normalized == 'active' ||
      normalized == 'new' ||
      normalized == 'in_stock' ||
      normalized == 'instock';
}

bool _isUnitAvailableForRequest(
  Map<String, dynamic> unit,
  Set<int> unavailableUnitIds,
) {
  final unitId = unit['unit_id'] as int?;
  if (unitId != null && unavailableUnitIds.contains(unitId)) {
    return false;
  }

  final normalized = (unit['status'] as String? ?? '').trim().toLowerCase();
  return _isUnitAvailableStatus(normalized) ||
      normalized == 'in_use' ||
      normalized == 'reserved' ||
      normalized == 'borrowed';
}

bool _isRejectedStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized.contains('rejected') || normalized.contains('denied');
}

bool _isBlockingReservationStatus(String? status) {
  final normalized = (status ?? '').trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return !normalized.contains('cancelled') &&
      !normalized.contains('canceled') &&
      !normalized.contains('rejected') &&
      !normalized.contains('denied') &&
      !normalized.contains('timed out') &&
      !normalized.contains('returned') &&
      !normalized.contains('void');
}

bool _sameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _reservationOverlapsWindow({
  required DateTime reservationStart,
  required DateTime reservationEnd,
  required DateTime requestStart,
  required DateTime requestEnd,
  DateTime? activityDate,
}) {
  // A finished event no longer holds the room or the equipment.
  if (!reservationEnd.isAfter(DateTime.now())) return false;
  final reservationDay = activityDate ?? reservationStart;
  if (!_sameCalendarDay(reservationDay, requestStart) ||
      !_sameCalendarDay(reservationDay, requestEnd)) {
    return false;
  }
  return reservationStart.isBefore(requestEnd) &&
      reservationEnd.isAfter(requestStart);
}

// MARK: - ReservationService

class ReservationService {
  static final ReservationService _instance = ReservationService._internal();

  factory ReservationService() {
    return _instance;
  }

  ReservationService._internal();

  SupabaseClient get _client => Supabase.instance.client;
  final Map<String, Map<String, dynamic>?> _officeByNameCache = {};
  final Map<int, Map<String, dynamic>?> _officeByIdCache = {};
  final Map<String, Future<Map<String, dynamic>?>> _officeByNameRequests = {};
  final Map<int, Future<Map<String, dynamic>?>> _officeByIdRequests = {};

  Future<_RequesterApprovalRouting> _resolveRequesterApprovalRouting(
    int userId, {
    required int? facultyApproverId,
  }) async {
    final profile = await _client
        .from('users')
        .select('role, affiliation, office_id')
        .eq('user_id', userId)
        .single();
    final role = (profile['role'] as String? ?? '').trim().toLowerCase();
    final affiliation = profile['affiliation'] as String?;
    final isDean = AuthService.isDeanRole(role);
    final roleProgramId = AuthService.programIdForProgramChairRole(role);
    final isProgramChair = roleProgramId != null;
    final affiliationProgramId = AuthService.programIdForAffiliation(
      affiliation,
    );
    if (!isDean && affiliationProgramId == null) {
      throw StateError(
        'Your profile affiliation is missing or does not match a supported academic program. Update your affiliation before submitting a reservation.',
      );
    }

    if (role == 'student' && facultyApproverId == null) {
      throw StateError(
        'Students must select the faculty member who granted permission before submitting.',
      );
    }

    if (isProgramChair && roleProgramId != affiliationProgramId) {
      throw StateError(
        'Your Program Chair role does not match your profile affiliation. Contact an administrator.',
      );
    }

    final deanOfficeId = isDean
        ? int.tryParse(profile['office_id']?.toString() ?? '')
        : await _getDeanOfficeIdForProgram(affiliationProgramId!);
    if (deanOfficeId == null) {
      throw StateError(
        'The Dean approval assignment has not been configured for your role or program. Contact an administrator before submitting.',
      );
    }
    final programChairOfficeId = isDean
        ? null
        : await getProgramOfficeId(affiliationProgramId!);

    return _RequesterApprovalRouting(
      isProgramChair: isProgramChair,
      isDean: isDean,
      programChairOfficeId: isProgramChair ? null : programChairOfficeId,
      deanOfficeId: deanOfficeId,
    );
  }

  Future<void> _insertRoutedApprovalRows({
    required int reservationId,
    required int? facultyApproverId,
    required List<int> officeIds,
    required _RequesterApprovalRouting routing,
  }) async {
    final officeNames = <int, String>{};
    for (final officeId in officeIds) {
      final office = await _getOfficeById(officeId);
      final name = (office?['department_name'] as String? ?? '').trim();
      if (name.isEmpty) {
        throw StateError(
          'The approval chain references an office that no longer exists.',
        );
      }
      officeNames[officeId] = name;
    }
    if (!officeNames.values.any(
      (name) => name.toLowerCase() == 'program chair',
    )) {
      throw StateError(
        'The approval chain does not include a Program Chair stage. Contact an administrator.',
      );
    }

    final baseTime = DateTime.now().toUtc();
    var firstOfficeStep = 0;
    if (facultyApproverId != null) {
      final timestamp = buildApprovalTimestampForStep(0, baseTime: baseTime);
      await _client.from('reservation_approvals').insert({
        'reservation_id': reservationId,
        'approver_user_id': facultyApproverId,
        'approval_stage': 'faculty',
        'status': 'Pending',
        'created_at': timestamp.toIso8601String(),
        'updated_at': timestamp.toIso8601String(),
      });
      firstOfficeStep = 1;
    }

    final routedRows = <Map<String, dynamic>>[];
    var routedOfficeStep = 0;
    for (var index = 0; index < officeIds.length; index++) {
      final sourceOfficeId = officeIds[index];
      final officeName = officeNames[sourceOfficeId]!;
      final isProgramChairStep = officeName.toLowerCase() == 'program chair';
      if (isProgramChairStep && routing.isDean) continue;
      final timestamp = buildApprovalTimestampForStep(
        routedOfficeStep + firstOfficeStep,
        baseTime: baseTime,
      );
      const status = 'Waiting';
      if (isProgramChairStep && routing.isProgramChair) {
        routedRows.add({
          'reservation_id': reservationId,
          'office_id': routing.deanOfficeId!,
          'approval_stage': 'dean',
          'status': status,
          'created_at': timestamp.toIso8601String(),
          'updated_at': timestamp.toIso8601String(),
        });
      } else if (isProgramChairStep) {
        routedRows
          ..add({
            'reservation_id': reservationId,
            'office_id': routing.programChairOfficeId!,
            'approval_stage': 'program_chair',
            'status': status,
            'created_at': timestamp.toIso8601String(),
            'updated_at': timestamp.toIso8601String(),
          })
          ..add({
            'reservation_id': reservationId,
            'office_id': routing.deanOfficeId!,
            'approval_stage': 'dean',
            'status': status,
            'created_at': timestamp.toIso8601String(),
            'updated_at': timestamp.toIso8601String(),
          });
      } else {
        routedRows.add({
          'reservation_id': reservationId,
          'office_id': sourceOfficeId,
          'approval_stage': 'office',
          'status': status,
          'created_at': timestamp.toIso8601String(),
          'updated_at': timestamp.toIso8601String(),
        });
      }
      routedOfficeStep++;
    }
    if (routedRows.isNotEmpty) {
      await _client.from('reservation_approvals').insert(routedRows);
    }
  }

  Future<int?> _getDeanOfficeIdForProgram(int programId) async {
    final assignment = await _client
        .from('dean_program_assignments')
        .select('dean_role')
        .eq('program_id', programId)
        .maybeSingle();
    final deanRole = assignment?['dean_role'] as String?;
    if (deanRole == null) return null;
    final deanOffice = await _client
        .from('dean_role_offices')
        .select('office_id')
        .eq('dean_role', deanRole)
        .maybeSingle();
    return deanOffice?['office_id'] as int?;
  }

  Future<void> _validateProgramChairStep(List<int> officeIds) async {
    for (final officeId in officeIds) {
      final office = await _getOfficeById(officeId);
      if ((office?['department_name'] as String?)?.trim().toLowerCase() ==
          'program chair') {
        return;
      }
    }
    throw StateError(
      'The approval chain does not include a Program Chair stage. Contact an administrator.',
    );
  }

  Future<List<FacultyProfile>> searchActiveFaculty(String query) async {
    final response = await _client.rpc(
      'search_active_faculty',
      params: {'p_search_query': query.trim()},
    );
    return (response as List)
        .map(
          (row) =>
              FacultyProfile.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
  }

  Future<List<FacultyApprovalRequest>> getFacultyApprovalRequests({
    required int facultyUserId,
  }) => _getApprovalRequests(facultyUserId: facultyUserId);

  Future<List<FacultyApprovalRequest>> getProgramChairApprovalRequests({
    required int officeId,
  }) => _getApprovalRequests(programChairOfficeId: officeId);

  Future<List<FacultyApprovalRequest>> getDeanApprovalRequests({
    required int officeId,
  }) => _getApprovalRequests(
    deanOfficeId: officeId,
    legacyDean:
        (AuthService.currentUser?['role']?.toString().toLowerCase() ?? '') ==
        'dean',
  );

  Future<int> getProgramOfficeId(int programId) async {
    final response = await _client
        .from('academic_programs')
        .select('office_id')
        .eq('program_id', programId)
        .maybeSingle();
    final officeId = response?['office_id'] as int?;
    if (officeId == null) {
      throw StateError(
        'Your assigned academic program has no Program Chair office. Contact an administrator.',
      );
    }
    return officeId;
  }

  Future<List<FacultyApprovalRequest>> _getApprovalRequests({
    int? facultyUserId,
    int? programChairOfficeId,
    int? deanOfficeId,
    bool legacyDean = false,
  }) async {
    if ([
          facultyUserId,
          programChairOfficeId,
          deanOfficeId,
        ].where((id) => id != null).length !=
        1) {
      throw ArgumentError(
        'Provide exactly one faculty user ID, program-chair office ID, or Dean office ID.',
      );
    }

    List<Map<String, dynamic>> rows(dynamic response) => (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList();

    final approvalsQuery = _client
        .from('reservation_approvals')
        .select(
          'approval_id, reservation_id, created_at, status, reconsideration_message',
        );
    final rawApprovalRows = facultyUserId != null
        ? await approvalsQuery
              .eq('approver_user_id', facultyUserId)
              .eq('status', 'Pending')
              .order('created_at')
        : programChairOfficeId != null
        ? await approvalsQuery
              .eq('approval_stage', 'program_chair')
              .eq('office_id', programChairOfficeId)
              .in_('status', [
                'Pending',
                'Condition Accepted',
                'Condition Rejected',
              ])
              .order('created_at')
        : await approvalsQuery
              .eq('approval_stage', legacyDean ? 'office' : 'dean')
              .eq('office_id', deanOfficeId!)
              .in_('status', [
                'Pending',
                'Condition Accepted',
                'Condition Rejected',
              ])
              .order('created_at');
    final approvalRows = rows(rawApprovalRows);
    if (approvalRows.isEmpty) return [];

    final reservationIds = approvalRows
        .map((row) => row['reservation_id'] as int)
        .toSet()
        .toList();
    final reservationRows = rows(
      await _client
          .from('reservations')
          .select(
            'reservation_id, user_id, activity_name, Date_of_Activity, '
            'Start_of_activity, End_of_Activity, created_at, outside_participants',
          )
          .in_('reservation_id', reservationIds),
    );
    final reservationsById = {
      for (final row in reservationRows) row['reservation_id'] as int: row,
    };
    final requesterIds = reservationRows
        .map((row) => row['user_id'] as int)
        .toSet()
        .toList();

    final requesterRows = requesterIds.isEmpty
        ? <Map<String, dynamic>>[]
        : rows(
            await _client
                .from('users')
                .select(
                  'user_id, full_name, first_name, middle_initial, last_name, email',
                )
                .in_('user_id', requesterIds),
          );
    final requestersById = {
      for (final row in requesterRows) row['user_id'] as int: row,
    };

    final roomLinks = rows(
      await _client
          .from('reservation_rooms')
          .select('reservation_id, room_id')
          .in_('reservation_id', reservationIds),
    );
    final roomIds = roomLinks
        .map((row) => row['room_id'] as int)
        .toSet()
        .toList();
    final roomRows = roomIds.isEmpty
        ? <Map<String, dynamic>>[]
        : rows(
            await _client
                .from('rooms')
                .select('room_id, room_number, room_type, room_table_type')
                .in_('room_id', roomIds),
          );
    final roomsById = {for (final row in roomRows) row['room_id'] as int: row};
    final roomNameByReservation = <int, String>{};
    for (final link in roomLinks) {
      final reservationId = link['reservation_id'] as int;
      final room = roomsById[link['room_id'] as int];
      if (room != null) {
        final tableType = (room['room_table_type'] as String?)?.trim();
        final roomDescription = '${room['room_type']} ${room['room_number']}'
            .trim();
        roomNameByReservation[reservationId] = tableType?.isNotEmpty == true
            ? '$roomDescription ($tableType tables)'
            : roomDescription;
      }
    }

    final itemLinks = rows(
      await _client
          .from('reservation_items')
          .select('reservation_id, reservation_items_id, item_id')
          .in_('reservation_id', reservationIds),
    );
    final itemIds = itemLinks
        .map((row) => row['item_id'] as int)
        .toSet()
        .toList();
    final itemRows = itemIds.isEmpty
        ? <Map<String, dynamic>>[]
        : rows(
            await _client
                .from('items')
                .select('item_id, item_name')
                .in_('item_id', itemIds),
          );
    final itemNamesById = {
      for (final row in itemRows)
        row['item_id'] as int: row['item_name'] as String,
    };
    final detailRows = rows(
      await _client
          .from('reservation_details')
          .select(
            'reservation_id, reservation_rooms_id, reservation_items_id, quantity',
          )
          .in_('reservation_id', reservationIds),
    );
    final quantitiesByItemLinkId = <int, int>{};
    final chairsByReservationId = <int, int>{};
    for (final row in detailRows) {
      final itemLinkId = row['reservation_items_id'] as int?;
      if (itemLinkId != null) {
        quantitiesByItemLinkId[itemLinkId] = row['quantity'] as int? ?? 1;
      } else if (row['reservation_rooms_id'] == null) {
        final reservationId = row['reservation_id'] as int;
        chairsByReservationId[reservationId] =
            (chairsByReservationId[reservationId] ?? 0) +
            (row['quantity'] as int? ?? 0);
      }
    }
    final itemSummariesByReservation = <int, List<String>>{};
    for (final link in itemLinks) {
      final reservationId = link['reservation_id'] as int;
      final itemId = link['item_id'] as int;
      final itemLinkId = link['reservation_items_id'] as int;
      final itemName = itemNamesById[itemId] ?? 'Item $itemId';
      final quantity = quantitiesByItemLinkId[itemLinkId] ?? 1;
      itemSummariesByReservation
          .putIfAbsent(reservationId, () => [])
          .add('$itemName (quantity: $quantity)');
    }

    final institutionalEventRows = rows(
      await _client
          .from('institutional_event_requests')
          .select('reservation_id')
          .in_('reservation_id', reservationIds),
    );
    final institutionalEventIds = institutionalEventRows
        .map((row) => row['reservation_id'] as int)
        .toSet();
    final eventResourcesByReservation =
        <int, List<InstitutionalEventResource>>{};
    final venueResourcesById = <int, InstitutionalEventResource>{};
    final venueRowsById = <int, Map<String, dynamic>>{};
    if (institutionalEventIds.isNotEmpty) {
      final eventVenueRows = rows(
        await _client
            .from('institutional_event_venues')
            .select(
              'event_venue_id, reservation_id, room_id, start_time, end_time, status, removal_reason',
            )
            .in_('reservation_id', institutionalEventIds.toList()),
      );
      for (final venue in eventVenueRows) {
        final eventVenueId = venue['event_venue_id'] as int;
        final room = roomsById[venue['room_id'] as int];
        final resource = InstitutionalEventResource(
          id: eventVenueId,
          kind: 'venue',
          name: room == null
              ? 'Venue ${venue['room_id']}'
              : '${room['room_type']} ${room['room_number']}'.trim(),
          status: venue['status'] as String? ?? 'included',
          startTime: DateTime.parse(venue['start_time'].toString()),
          endTime: DateTime.parse(venue['end_time'].toString()),
          removalReason: venue['removal_reason'] as String?,
        );
        venueRowsById[eventVenueId] = venue;
        venueResourcesById[eventVenueId] = resource;
        eventResourcesByReservation
            .putIfAbsent(venue['reservation_id'] as int, () => [])
            .add(resource);
      }

      final equipmentRows = rows(
        await _client
            .from('institutional_event_equipment')
            .select(
              'event_equipment_id, reservation_id, event_venue_id, reservation_items_id, status, removal_reason',
            )
            .in_('reservation_id', institutionalEventIds.toList()),
      );
      final itemLinksById = {
        for (final link in itemLinks) link['reservation_items_id'] as int: link,
      };
      for (final equipment in equipmentRows) {
        final itemLinkId = equipment['reservation_items_id'] as int;
        final itemLink = itemLinksById[itemLinkId];
        final itemId = itemLink?['item_id'] as int?;
        final venueId = equipment['event_venue_id'] as int;
        final venue = venueRowsById[venueId];
        final venueResource = venueResourcesById[venueId];
        eventResourcesByReservation
            .putIfAbsent(equipment['reservation_id'] as int, () => [])
            .add(
              InstitutionalEventResource(
                id: equipment['event_equipment_id'] as int,
                kind: 'equipment',
                name: itemId == null
                    ? 'Equipment'
                    : itemNamesById[itemId] ?? 'Item $itemId',
                status: equipment['status'] as String? ?? 'included',
                quantity: quantitiesByItemLinkId[itemLinkId] ?? 1,
                venueName: venueResource?.name,
                startTime: venue == null
                    ? null
                    : DateTime.parse(venue['start_time'].toString()),
                endTime: venue == null
                    ? null
                    : DateTime.parse(venue['end_time'].toString()),
                removalReason: equipment['removal_reason'] as String?,
              ),
            );
      }
    }

    final requests = <FacultyApprovalRequest>[];
    for (final approval in approvalRows) {
      final reservationId = approval['reservation_id'] as int;
      final reservation = reservationsById[reservationId];
      if (reservation == null) continue;
      final requester = requestersById[reservation['user_id'] as int];
      final requesterFullName = (requester?['full_name'] as String?)?.trim();
      final requesterName = requesterFullName?.isNotEmpty == true
          ? requesterFullName!
          : [
                  requester?['first_name'],
                  requester?['middle_initial'],
                  requester?['last_name'],
                ]
                .whereType<String>()
                .where((part) => part.trim().isNotEmpty)
                .join(' ');

      requests.add(
        FacultyApprovalRequest(
          approvalId: approval['approval_id'] as int,
          reservationId: reservationId,
          activityName: reservation['activity_name'] as String,
          requesterName: requesterName.isEmpty
              ? 'Student requester'
              : requesterName,
          requesterEmail: requester?['email'] as String? ?? '',
          dateOfActivity: DateTime.parse(
            reservation['Date_of_Activity'].toString(),
          ),
          startTime: DateTime.parse(
            reservation['Start_of_activity'].toString(),
          ),
          endTime: DateTime.parse(reservation['End_of_Activity'].toString()),
          submittedAt: DateTime.parse(reservation['created_at'].toString()),
          hasOutsideParticipants:
              reservation['outside_participants'] as bool? ?? false,
          itemSummaries: institutionalEventIds.contains(reservationId)
              ? const []
              : itemSummariesByReservation[reservationId] ?? const [],
          chairsQuantity: chairsByReservationId[reservationId],
          roomName: roomNameByReservation[reservationId],
          status: approval['status'] as String? ?? 'Pending',
          reconsiderationMessage:
              approval['reconsideration_message'] as String?,
          institutionalEventResources:
              eventResourcesByReservation[reservationId] ?? const [],
        ),
      );
    }
    return requests;
  }

  Future<void> respondToFacultyApproval({
    required int approvalId,
    required bool approved,
    String? rejectionReason,
  }) async {
    final result = await _client.rpc(
      'respond_to_faculty_approval',
      params: {
        'p_approval_id': approvalId,
        'p_decision': approved ? 'approve' : 'reject',
        'p_rejection_reason': rejectionReason,
      },
    );
    if (result != true) {
      throw StateError('The faculty approval response was not confirmed.');
    }
  }

  Future<void> respondToProgramChairApproval({
    required int approvalId,
    required String decision,
    String? message,
    String? rejectionReason,
  }) async {
    final result = await _client.rpc(
      'respond_to_program_chair_approval',
      params: {
        'p_approval_id': approvalId,
        'p_decision': decision,
        'p_message': message,
        'p_rejection_reason': rejectionReason,
      },
    );
    if (result != true) {
      throw StateError('The program-chair response was not confirmed.');
    }
  }

  Future<void> respondToDeanApproval({
    required int approvalId,
    required String decision,
    String? message,
    String? rejectionReason,
  }) async {
    final result = await _client.rpc(
      'respond_to_dean_approval',
      params: {
        'p_approval_id': approvalId,
        'p_decision': decision,
        'p_message': message,
        'p_rejection_reason': rejectionReason,
      },
    );
    if (result != true) {
      throw StateError('The Dean approval response was not confirmed.');
    }
  }

  Future<void> respondToInstitutionalEventApproval({
    required int approvalId,
    required String decision,
    String? message,
    String? rejectionReason,
    List<int> removedVenueIds = const [],
    List<int> removedEquipmentIds = const [],
  }) async {
    final response = await _client.rpc(
      'respond_to_institutional_event_approval',
      params: {
        'p_approval_id': approvalId,
        'p_decision': decision,
        'p_message': message,
        'p_rejection_reason': rejectionReason,
        'p_removed_venue_ids': removedVenueIds,
        'p_removed_equipment_ids': removedEquipmentIds,
      },
    );
    if (response != true) {
      throw StateError('The Institutional Event response was not confirmed.');
    }
  }

  Future<Map<String, dynamic>?> getRequesterReconsideration(
    int reservationId,
  ) async {
    final response = await _client
        .from('reservation_approvals')
        .select(
          'approval_id, approval_stage, reconsideration_message, condition_responded_at',
        )
        .eq('reservation_id', reservationId)
        .in_('approval_stage', ['program_chair', 'dean'])
        .eq('status', 'Condition Requested')
        .maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  }

  Future<void> respondToReconsideration({
    required int approvalId,
    required bool accepted,
  }) async {
    final result = await _client.rpc(
      'respond_to_reconsideration',
      params: {
        'p_approval_id': approvalId,
        'p_decision': accepted ? 'accept' : 'reject',
      },
    );
    if (result != true) {
      throw StateError('The reconsideration response was not confirmed.');
    }
  }

  Future<bool> shouldPromptExperienceRating(int reservationId) async {
    final result = await _client.rpc(
      'should_prompt_experience_rating',
      params: {'p_reservation_id': reservationId},
    );
    return result == true;
  }

  Future<void> submitExperienceRating({
    required int reservationId,
    required int rating,
  }) async {
    await _client.rpc(
      'submit_experience_rating',
      params: {'p_reservation_id': reservationId, 'p_rating': rating},
    );
  }

  static String resolveApprovalStatusFromRows({
    required String overallStatus,
    required List<Map<String, dynamic>> approvalRows,
  }) {
    final normalizedOverallStatus = overallStatus.trim().toLowerCase();
    if (normalizedOverallStatus == 'to return' ||
        normalizedOverallStatus == 'timed out' ||
        normalizedOverallStatus == 'overdue' ||
        normalizedOverallStatus == 'returned' ||
        normalizedOverallStatus == 'cancelled' ||
        normalizedOverallStatus == 'canceled' ||
        normalizedOverallStatus == 'rejected' ||
        normalizedOverallStatus == 'denied') {
      return overallStatus;
    }

    if (approvalRows.isEmpty) {
      return overallStatus.trim().isNotEmpty
          ? overallStatus
          : 'Pending Approval';
    }

    var completedCount = 0;
    var hasPending = false;
    var hasRejected = false;
    var hasCancelled = false;
    var hasReturned = false;

    for (final row in approvalRows) {
      final normalized = (row['status'] as String? ?? '').trim().toLowerCase();
      if (normalized.isEmpty) continue;

      if (normalized.contains('rejected') || normalized.contains('denied')) {
        hasRejected = true;
      } else if (normalized.contains('cancelled') ||
          normalized.contains('canceled')) {
        hasCancelled = true;
      } else if (normalized.contains('returned')) {
        hasReturned = true;
      } else if (normalized.contains('pending') ||
          normalized.contains('processing') ||
          normalized.contains('waiting') ||
          normalized.contains('review')) {
        hasPending = true;
      } else if (normalized.contains('returned') ||
          normalized.contains('completed') ||
          normalized.contains('complete') ||
          normalized.contains('approved') ||
          normalized.contains('accepted')) {
        completedCount++;
      } else {
        hasPending = true;
      }
    }

    if (hasReturned) return 'Returned';
    if (hasRejected) return 'Rejected';
    if (hasPending) {
      return 'Pending Approval';
    }
    if (hasCancelled) return 'Cancelled';
    if (completedCount < approvalRows.length) return 'Pending Approval';

    final hasCompleted = approvalRows.any((row) {
      final normalized = (row['status'] as String? ?? '').trim().toLowerCase();
      return normalized.contains('completed') ||
          normalized.contains('complete');
    });
    return hasCompleted ? 'Completed' : 'Approved';
  }

  static int normalizeItemUsage(int total, int usage) {
    return ItemModel.normalizeItemUsage(total, usage);
  }

  static int normalizeAvailableQuantity(int total, int usage) {
    return ItemModel.normalizeAvailableQuantity(total, usage);
  }

  Future<String?> enforceReservationLifecycle() async {
    final response = await _client.rpc('get_current_reservation_return_lock');
    if (response == null) return null;
    if (response is! String) {
      throw const FormatException(
        'The reservation eligibility check returned an invalid response.',
      );
    }
    final message = response.trim();
    return message.isEmpty ? null : message;
  }

  String? reservationReturnLockFromError(Object error) {
    const prefix = 'Please accomplish return/settle your reservation.';
    final message = error.toString();
    final start = message.indexOf(prefix);
    if (start < 0) return null;
    final detailsStart = message.indexOf(', code:', start);
    return detailsStart < 0
        ? message.substring(start)
        : message.substring(start, detailsStart);
  }

  Future<void> _recalculateItemUsageFromUnits(int itemId) async {
    try {
      final unitsResp = await _client
          .from('item_units')
          .select('unit_id, status')
          .eq('item_id', itemId);

      final units =
          (unitsResp as List?)?.cast<Map<String, dynamic>>() ??
          const <Map<String, dynamic>>[];
      final totalUnits = units.length;
      final availableUnits = units.where((unit) {
        final unitId = unit['unit_id'] as int?;
        if (unitId == null) return false;
        return _isUnitAvailableStatus(unit['status'] as String?);
      }).length;

      final normalizedInUse = normalizeItemUsage(
        totalUnits,
        totalUnits - availableUnits,
      );
      await _client
          .from('items')
          .update({
            'quantity_in_use': normalizedInUse,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('item_id', itemId);
    } catch (_) {
      // Best-effort recalculation; do not fail a reservation flow because of stale counters.
    }
  }

  // MARK: - Room Operations

  /// Fetch all rooms of a specific type
  Future<List<Room>> getRoomsByType(String roomType) async {
    try {
      final response = await _client
          .from('rooms')
          .select()
          .eq('room_type', roomType)
          .eq('maintenance_status', false)
          .eq('availability_status', true);

      return (response as List)
          .map((room) => Room.fromJson(room as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching rooms: $e');
      return [];
    }
  }

  /// Get rooms filtered by type and table type (for classrooms)
  Future<List<Room>> getClassroomsByTableType(String tableType) async {
    try {
      // Fetch all classrooms and filter by table type (case-insensitive in memory)
      final response = await _client
          .from('rooms')
          .select()
          .eq('room_type', 'Classroom')
          .eq('maintenance_status', false)
          .eq('availability_status', true);

      // Normalize for comparison: remove spaces and convert to lowercase
      final normalizedTableType = tableType.replaceAll(' ', '').toLowerCase();

      // Filter results by table type (case-insensitive, space-insensitive)
      final filteredRooms = (response as List).where((room) {
        final roomTableType = room['room_table_type'] as String?;
        final normalizedRoomType =
            roomTableType?.replaceAll(' ', '').toLowerCase() ?? '';
        final matches = normalizedRoomType == normalizedTableType;

        return matches;
      }).toList();

      return filteredRooms
          .map((room) => Room.fromJson(room as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching classrooms: $e');
      return [];
    }
  }

  /// A room is taken while another booking overlaps this time, including
  /// requests that are still waiting for approval. Rejected, cancelled, and
  /// non-overlapping times leave the room available.
  Future<bool> hasTimeConflict({
    required int roomId,
    required DateTime startTime,
    required DateTime endTime,
    required DateTime reservationDate,
  }) {
    return _roomTimeIsTaken(
      roomId: roomId,
      reservationDate: reservationDate,
      startTime: startTime,
      endTime: endTime,
    );
  }

  Set<int> _roomIdsFromRpc(dynamic result) {
    final ids = <int>{};
    if (result is List) {
      for (final raw in result) {
        if (raw is Map) {
          final id = _asInt(raw['room_id']);
          if (id != null) ids.add(id);
          continue;
        }
        final id = _asInt(raw);
        if (id != null) ids.add(id);
      }
      return ids;
    }
    if (result is String) {
      final inner = result
          .replaceAll('{', '')
          .replaceAll('}', '')
          .replaceAll('[', '')
          .replaceAll(']', '')
          .trim();
      if (inner.isEmpty) return <int>{};
      return inner
          .split(',')
          .map((part) => int.tryParse(part.trim()))
          .whereType<int>()
          .toSet();
    }
    final single = _asInt(result);
    if (single == null) return <int>{};
    return {single};
  }

  /// Room ids already booked by any account for this exact overlap.
  Future<Set<int>> takenRoomIds({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final result = await _client.rpc(
      'taken_room_ids',
      params: {
        'p_start_of_activity': _scheduleTimestamp(startTime),
        'p_end_of_activity': _scheduleTimestamp(endTime),
      },
    );
    return _roomIdsFromRpc(result);
  }

  Future<Map<int, int>> getInstitutionalEventEquipmentAvailability({
    required List<int> itemIds,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (itemIds.isEmpty) return const {};
    try {
      final result = await _client.rpc(
        'institutional_event_item_availability',
        params: {
          'p_item_ids': itemIds,
          'p_start_of_activity': _scheduleTimestamp(startTime),
          'p_end_of_activity': _scheduleTimestamp(endTime),
        },
      );
      if (result is! List) {
        throw StateError(
          'Equipment availability was not returned by the server.',
        );
      }
      final availability = <int, int>{};
      for (final row in result) {
        if (row is! Map) {
          throw StateError('Equipment availability response was invalid.');
        }
        final itemId = _asInt(row['item_id']);
        final availableQuantity = _asInt(row['available_quantity']);
        if (itemId == null || availableQuantity == null) {
          throw StateError('Equipment availability response was incomplete.');
        }
        availability[itemId] = availableQuantity;
      }
      return availability;
    } catch (availabilityError) {
      try {
        final unitsResponse = await _client
            .from('item_units')
            .select('unit_id, item_id, status')
            .in_('item_id', itemIds);
        if (unitsResponse is! List) {
          throw StateError('Equipment inventory was not returned.');
        }
        final reservedResponse = await _client.rpc(
          'reserved_item_unit_ids',
          params: {
            'p_item_ids': itemIds,
            'p_start_of_activity': _scheduleTimestamp(startTime),
            'p_end_of_activity': _scheduleTimestamp(endTime),
          },
        );
        if (reservedResponse is! List) {
          throw StateError('Reserved equipment units were not returned.');
        }

        final reservedUnitIds = <int>{};
        for (final row in reservedResponse) {
          if (row is! Map) {
            throw StateError('Reserved equipment response was invalid.');
          }
          final unitId = _asInt(row['unit_id']);
          if (unitId != null) reservedUnitIds.add(unitId);
        }

        final availability = {for (final id in itemIds) id: 0};
        for (final rawUnit in unitsResponse) {
          if (rawUnit is! Map) {
            throw StateError('Equipment inventory response was invalid.');
          }
          final unitId = _asInt(rawUnit['unit_id']);
          final itemId = _asInt(rawUnit['item_id']);
          if (unitId == null ||
              itemId == null ||
              reservedUnitIds.contains(unitId) ||
              !_isUnitAvailableStatus(rawUnit['status']?.toString())) {
            continue;
          }
          availability.update(itemId, (count) => count + 1, ifAbsent: () => 1);
        }
        return availability;
      } catch (fallbackError) {
        throw StateError(
          'Could not verify equipment availability. Apply database migration '
          '0027 and confirm migration 0026 is installed. '
          'Availability check error: $availabilityError. '
          'Fallback check error: $fallbackError',
        );
      }
    }
  }

  Future<bool> _roomTimeIsTaken({
    required int roomId,
    required DateTime reservationDate,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final taken = await takenRoomIds(startTime: startTime, endTime: endTime);
    return taken.contains(roomId);
  }

  /// Get all reservations for a specific room on a specific date
  Future<List<ReservationSlot>> getRoomReservationsForDate(
    int roomId,
    DateTime date,
  ) async {
    try {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final response = await _client
          .from('reservations')
          .select(
            'reservation_id, Date_of_Activity, Start_of_activity, End_of_Activity, overall_status',
          )
          .gte('Date_of_Activity', dayStart.toIso8601String())
          .lt('Date_of_Activity', dayEnd.toIso8601String())
          .neq('overall_status', 'Cancelled');

      final reservations = <ReservationSlot>[];

      for (final res in response as List) {
        final detailResponse = await _client
            .from('reservation_details')
            .select('reservation_rooms_id')
            .eq('reservation_id', res['reservation_id']);

        for (final detail in detailResponse as List) {
          final roomReservationId = detail['reservation_rooms_id'] as int?;
          if (roomReservationId == null) {
            continue;
          }

          final roomSelection = await _client
              .from('reservation_rooms')
              .select('room_id')
              .eq('reservation_rooms_id', roomReservationId)
              .maybeSingle();

          if (roomSelection != null && roomSelection['room_id'] == roomId) {
            reservations.add(
              ReservationSlot(
                startTime: DateTime.parse(res['Start_of_activity'] as String),
                endTime: DateTime.parse(res['End_of_Activity'] as String),
                roomId: roomId,
                reservationId: res['reservation_id'] as int,
                status: res['overall_status'] as String? ?? 'Pending',
              ),
            );
            break;
          }
        }
      }

      return reservations;
    } catch (e) {
      print('Error fetching room reservations: $e');
      return [];
    }
  }

  // MARK: - Item Operations

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _scheduleTimestamp(DateTime value) {
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }

  /// Unit ids held by any account during this time. Other students cannot
  /// read those reservations directly, so stock has to come from this check.
  Future<Map<int, Set<int>>> _unavailableUnitsOnSharedSchedule(
    List<int> itemIds,
    DateTime requestStart,
    DateTime requestEnd,
  ) async {
    final result = await _client.rpc(
      'reserved_item_unit_ids',
      params: {
        'p_item_ids': itemIds,
        'p_start_of_activity': _scheduleTimestamp(requestStart),
        'p_end_of_activity': _scheduleTimestamp(requestEnd),
      },
    );

    final unavailableByItem = <int, Set<int>>{};
    for (final raw in (result as List? ?? const [])) {
      if (raw is! Map) continue;
      final itemId = _asInt(raw['item_id']);
      final unitId = _asInt(raw['unit_id']);
      if (itemId == null || unitId == null) continue;
      unavailableByItem.putIfAbsent(itemId, () => <int>{}).add(unitId);
    }
    return unavailableByItem;
  }

  Future<Map<int, Set<int>>> _getUnavailableUnitIdsForItems(
    List<int> itemIds, {
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    final unavailableByItem = <int, Set<int>>{};
    if (itemIds.isEmpty) return unavailableByItem;
    if (requestStart == null || requestEnd == null) return unavailableByItem;

    final targetStart = requestStart;
    final targetEnd = requestEnd;

    try {
      return await _unavailableUnitsOnSharedSchedule(
        itemIds,
        targetStart,
        targetEnd,
      );
    } catch (e) {
      print('Shared equipment availability unavailable: $e');
    }

    try {
      final reservationItemsResponse = await _client
          .from('reservation_items')
          .select('reservation_items_id, item_id')
          .in_('item_id', itemIds);

      if (reservationItemsResponse == null) return unavailableByItem;

      final reservationItems = (reservationItemsResponse as List)
          .cast<Map<String, dynamic>>();
      if (reservationItems.isEmpty) return unavailableByItem;

      final reservationItemsIdToItemId = <int, int>{};
      final reservationItemsIds = <int>[];
      for (final row in reservationItems) {
        final reservationItemsId = row['reservation_items_id'] as int?;
        final itemId = row['item_id'] as int?;
        if (reservationItemsId == null || itemId == null) continue;
        reservationItemsIdToItemId[reservationItemsId] = itemId;
        reservationItemsIds.add(reservationItemsId);
      }

      if (reservationItemsIds.isEmpty) return unavailableByItem;

      final reservationDetailsResponse = await _client
          .from('reservation_details')
          .select('reservation_id, reservation_items_id')
          .in_('reservation_items_id', reservationItemsIds);

      if (reservationDetailsResponse == null) return unavailableByItem;

      final reservationDetails = (reservationDetailsResponse as List)
          .cast<Map<String, dynamic>>();
      final reservationIds = <int>[];
      final reservationIdToReservationItemsIds = <int, List<int>>{};

      for (final row in reservationDetails) {
        final reservationId = row['reservation_id'] as int?;
        final reservationItemsId = row['reservation_items_id'] as int?;
        if (reservationId == null || reservationItemsId == null) continue;
        reservationIdToReservationItemsIds
            .putIfAbsent(reservationId, () => <int>[])
            .add(reservationItemsId);
        reservationIds.add(reservationId);
      }

      if (reservationIds.isEmpty) return unavailableByItem;

      final reservationsResponse = await _client
          .from('reservations')
          .select(
            'reservation_id, overall_status, Date_of_Activity, Start_of_activity, End_of_Activity',
          )
          .in_('reservation_id', reservationIds);

      if (reservationsResponse == null) return unavailableByItem;

      final reservations = (reservationsResponse as List)
          .cast<Map<String, dynamic>>();
      final approvalStatusesByReservation = <int, List<String>>{};
      final approvalResponse = await _client
          .from('reservation_approvals')
          .select('reservation_id, status')
          .in_('reservation_id', reservationIds);
      for (final rawApproval
          in (approvalResponse as List).cast<Map<String, dynamic>>()) {
        final reservationId = rawApproval['reservation_id'] as int?;
        if (reservationId == null) continue;
        approvalStatusesByReservation
            .putIfAbsent(reservationId, () => <String>[])
            .add((rawApproval['status'] ?? '').toString().trim().toLowerCase());
      }

      final activeReservationItemIds = <int>{};
      for (final row in reservations) {
        final reservationId = row['reservation_id'] as int?;
        final status = row['overall_status'] as String?;
        if (reservationId == null || !_isBlockingReservationStatus(status))
          continue;
        final approvalStatuses =
            approvalStatusesByReservation[reservationId] ?? const <String>[];
        if (approvalStatuses.any(
          (approvalStatus) =>
              approvalStatus.contains('cancelled') ||
              approvalStatus.contains('canceled') ||
              approvalStatus.contains('rejected') ||
              approvalStatus.contains('denied') ||
              approvalStatus.contains('returned'),
        )) {
          continue;
        }

        final activityRaw = row['Date_of_Activity'] as String?;
        final reservationStartRaw = row['Start_of_activity'] as String?;
        final reservationEndRaw = row['End_of_Activity'] as String?;
        if (reservationStartRaw == null || reservationEndRaw == null) continue;

        try {
          final reservationStart = DateTime.parse(reservationStartRaw);
          final reservationEnd = DateTime.parse(reservationEndRaw);
          final activityDate = activityRaw == null
              ? null
              : DateTime.parse(activityRaw);
          if (!_reservationOverlapsWindow(
            reservationStart: reservationStart,
            reservationEnd: reservationEnd,
            requestStart: targetStart,
            requestEnd: targetEnd,
            activityDate: activityDate,
          )) {
            continue;
          }
        } catch (_) {
          continue;
        }

        for (final reservationItemsId
            in reservationIdToReservationItemsIds[reservationId] ??
                const <int>[]) {
          activeReservationItemIds.add(reservationItemsId);
        }
      }

      if (activeReservationItemIds.isEmpty) return unavailableByItem;

      final reservationUnitsResponse = await _client
          .from('reservation_item_units')
          .select('reservation_items_id, unit_id')
          .in_('reservation_items_id', activeReservationItemIds.toList());

      if (reservationUnitsResponse == null) return unavailableByItem;

      for (final row
          in (reservationUnitsResponse as List).cast<Map<String, dynamic>>()) {
        final reservationItemsId = row['reservation_items_id'] as int?;
        final unitId = row['unit_id'] as int?;
        final itemId = reservationItemsIdToItemId[reservationItemsId];
        if (unitId == null || itemId == null) continue;
        unavailableByItem.putIfAbsent(itemId, () => <int>{}).add(unitId);
      }
    } catch (e) {
      print('Error resolving unavailable item units: $e');
    }

    return unavailableByItem;
  }

  /// Fetch all available items from the database
  Future<List<ItemModel>> getAllItems({
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    try {
      final response = await _client
          .from('items')
          .select('*, item_owners(owner_name)');

      if (response == null) return [];

      final itemsList = (response as List).cast<Map<String, dynamic>>();

      // Collect item ids then fetch units in bulk to compute totals and available counts.
      final itemIds = itemsList.map((m) => m['item_id'] as int).toList();
      final unitsResp = await _client
          .from('item_units')
          .select('unit_id, item_id, status')
          .in_('item_id', itemIds);

      final units = (unitsResp as List?)?.cast<Map<String, dynamic>>() ?? [];
      final unavailableByItem = await _getUnavailableUnitIdsForItems(
        itemIds,
        requestStart: requestStart,
        requestEnd: requestEnd,
      );

      final unitsByItem = <int, List<Map<String, dynamic>>>{};
      for (final u in units) {
        final iid = u['item_id'] as int?;
        if (iid == null) continue;
        unitsByItem.putIfAbsent(iid, () => <Map<String, dynamic>>[]).add(u);
      }

      return itemsList.map((item) {
        final id = item['item_id'] as int;
        final itemUnits = unitsByItem[id] ?? const <Map<String, dynamic>>[];
        final total = itemUnits.isNotEmpty
            ? itemUnits.length
            : (item['quantity_total'] as int? ?? 0);
        final unavailableUnitIds = unavailableByItem[id] ?? const <int>{};
        final available = itemUnits.where((u) {
          return _isUnitAvailableForRequest(u, unavailableUnitIds);
        }).length;
        final clampedAvailable = available.clamp(0, total);
        final inUse = ItemModel.normalizeItemUsage(
          total,
          total - clampedAvailable,
        );

        return ItemModel(
          itemId: id,
          itemName: item['item_name'] as String? ?? 'Unknown',
          quantityTotal: total,
          quantityInUse: inUse,
          ownerId: item['owner_id'] as int?,
          ownerName: item['item_owners']?['owner_name'] as String?,
          maintenanceStatus: item['maintenance_status'] as bool? ?? false,
          availabilityStatus: item['availability_status'] as bool? ?? true,
        );
      }).toList();
    } catch (e) {
      print('Error fetching items: $e');
      return [];
    }
  }

  /// Get item details including current usage
  Future<ItemModel?> getItemDetails(
    int itemId, {
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    try {
      final response = await _client
          .from('items')
          .select('*, item_owners(owner_name)')
          .eq('item_id', itemId)
          .single();

      if (response == null) return null;

      final item = Map<String, dynamic>.from(response as Map);

      final unitsResp = await _client
          .from('item_units')
          .select('unit_id, status')
          .eq('item_id', itemId);

      final units = (unitsResp as List?)?.cast<Map<String, dynamic>>() ?? [];
      final unavailableUnitIds = await _getUnavailableUnitIdsForItems(
        [itemId],
        requestStart: requestStart,
        requestEnd: requestEnd,
      );
      final total = units.length;
      final available = units.where((u) {
        return _isUnitAvailableForRequest(
          u,
          unavailableUnitIds[itemId] ?? const <int>{},
        );
      }).length;
      final clampedAvailable = available.clamp(0, total);
      final inUse = ItemModel.normalizeItemUsage(
        total,
        total - clampedAvailable,
      );

      // Debug: if availability is unexpectedly zero, print unit details to help diagnose
      if (available == 0) {
        try {
          print(
            'Debug getItemDetails - item_id=$itemId total=$total available=$available units=',
          );
          for (final u in units) {
            print(
              '  unit: unit_id=${u['unit_id']}, unit_code=${u['unit_code'] ?? 'N/A'}, status=${u['status'] ?? 'N/A'}',
            );
          }
        } catch (_) {}
      }

      return ItemModel(
        itemId: item['item_id'] as int,
        itemName: item['item_name'] as String? ?? 'Unknown',
        quantityTotal: total,
        quantityInUse: inUse,
        ownerId: item['owner_id'] as int?,
        ownerName: item['item_owners']?['owner_name'] as String?,
        maintenanceStatus: item['maintenance_status'] as bool? ?? false,
        availabilityStatus: item['availability_status'] as bool? ?? true,
      );
    } catch (e) {
      print('Error fetching item details: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> _getAvailableItemUnits(
    int itemId,
    int quantity, {
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    try {
      final response = await _client
          .from('item_units')
          .select('unit_id, unit_code, status')
          .eq('item_id', itemId)
          .order('unit_id', ascending: true);

      if (response == null) return [];

      final units = (response as List).cast<Map<String, dynamic>>();
      final unavailableUnitIds = await _getUnavailableUnitIdsForItems(
        [itemId],
        requestStart: requestStart,
        requestEnd: requestEnd,
      );

      return units
          .where((unit) {
            return _isUnitAvailableForRequest(
              unit,
              unavailableUnitIds[itemId] ?? const <int>{},
            );
          })
          .take(quantity)
          .toList();
    } catch (e) {
      print('Error fetching available item units: $e');
      return [];
    }
  }

  Future<void> _reserveItemUnitsForReservation({
    required int reservationItemsId,
    required int itemId,
    required int quantity,
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    final availableUnits = await _getAvailableItemUnits(
      itemId,
      quantity,
      requestStart: requestStart,
      requestEnd: requestEnd,
    );
    if (availableUnits.length < quantity) {
      throw Exception(
        'Not enough available units for item $itemId: requested $quantity, available ${availableUnits.length}',
      );
    }

    final now = DateTime.now().toIso8601String();

    for (final unit in availableUnits) {
      final unitId = unit['unit_id'] as int?;
      if (unitId == null) continue;

      final reservationLinkPayload = {
        'reservation_items_id': reservationItemsId,
        'unit_id': unitId,
        'created_at': now,
        'updated_at': now,
      };

      try {
        final insertResponse = await _client
            .from('reservation_item_units')
            .insert(reservationLinkPayload)
            .select();
        if (insertResponse == null || (insertResponse as List).isEmpty) {
          throw Exception(
            'Failed to link unit $unitId to reservation item $reservationItemsId',
          );
        }
      } catch (e) {
        print('Primary reservation_item_units insert failed: $e');
        final serviceRoleKey = SupabaseService.serviceRoleKey;
        if (serviceRoleKey.isEmpty) {
          rethrow;
        }

        final serviceClient = SupabaseClient(
          _client.supabaseUrl,
          serviceRoleKey,
        );
        final insertResponse = await serviceClient
            .from('reservation_item_units')
            .insert(reservationLinkPayload)
            .select();
        if (insertResponse == null || (insertResponse as List).isEmpty) {
          throw Exception(
            'Failed to link unit $unitId to reservation item $reservationItemsId',
          );
        }
      }

      try {
        final updateResponse = await _client
            .from('item_units')
            .update({'status': 'in_use', 'updated_at': now})
            .eq('unit_id', unitId)
            .select();

        if (updateResponse == null || (updateResponse as List).isEmpty) {
          throw Exception('Failed to reserve item unit $unitId');
        }
      } catch (e) {
        print('Primary item_units update failed: $e');
        final serviceRoleKey = SupabaseService.serviceRoleKey;
        if (serviceRoleKey.isEmpty) {
          rethrow;
        }

        final serviceClient = SupabaseClient(
          _client.supabaseUrl,
          serviceRoleKey,
        );
        final updateResponse = await serviceClient
            .from('item_units')
            .update({'status': 'in_use', 'updated_at': now})
            .eq('unit_id', unitId)
            .select();

        if (updateResponse == null || (updateResponse as List).isEmpty) {
          throw Exception('Failed to reserve item unit $unitId');
        }
      }
    }
  }

  /// Fetch reservations created by a specific user.
  Future<List<ReservationRecord>> getReservationRecordsForUser(
    int userId, {
    bool includeDetails = true,
  }) async {
    try {
      final reservationsResponse = await _client
          .from('reservations')
          .select(
            'reservation_id, activity_name, overall_status, created_at, updated_at, Date_of_Activity, Start_of_activity, End_of_Activity',
          )
          .eq('user_id', userId)
          .order('Date_of_Activity', ascending: false);

      if (reservationsResponse == null) {
        return [];
      }

      final resList = reservationsResponse as List;
      final requesterProfile = await _client
          .from('users')
          .select('role')
          .eq('user_id', userId)
          .maybeSingle();
      final requesterIsDean = AuthService.isDeanRole(
        requesterProfile?['role']?.toString(),
      );
      final reservationIds = resList
          .map((res) => res['reservation_id'] as int?)
          .whereType<int>()
          .toList();

      final approvalsResponse = reservationIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _client
                .from('reservation_approvals')
                .select(
                  'reservation_id, office_id, approver_user_id, approval_stage, '
                  'status, approved_at, created_at, updated_at, rejection_reason, '
                  'reconsideration_message, requester_condition_response',
                )
                .in_('reservation_id', reservationIds);

      final approvalRowsByReservation = <int, List<Map<String, dynamic>>>{};
      if (approvalsResponse != null) {
        for (final approval in approvalsResponse as List) {
          final reservationId = approval['reservation_id'] as int?;
          if (reservationId == null) {
            continue;
          }
          approvalRowsByReservation
              .putIfAbsent(reservationId, () => [])
              .add(Map<String, dynamic>.from(approval as Map<String, dynamic>));
        }
      }

      final futures = resList.map((res) async {
        try {
          final reservationId = res['reservation_id'] as int;
          final date = DateTime.parse(res['Date_of_Activity'] as String);
          final startTime = DateTime.parse(res['Start_of_activity'] as String);
          final endTime = DateTime.parse(res['End_of_Activity'] as String);
          final reservationTime =
              '${_formatDateTime(startTime)} - ${_formatDateTime(endTime)}';
          final effectiveStatus = resolveApprovalStatusFromRows(
            overallStatus:
                (res['overall_status'] as String?) ?? 'Pending Approval',
            approvalRows: approvalRowsByReservation[reservationId] ?? const [],
          );
          final rejectedApproval =
              (approvalRowsByReservation[reservationId] ??
                      const <Map<String, dynamic>>[])
                  .where((approval) {
                    final status = (approval['status'] as String? ?? '')
                        .trim()
                        .toLowerCase();
                    return status == 'rejected' || status == 'denied';
                  })
                  .toList()
                ..sort((a, b) {
                  final aCreated = DateTime.tryParse(
                    a['created_at']?.toString() ?? '',
                  );
                  final bCreated = DateTime.tryParse(
                    b['created_at']?.toString() ?? '',
                  );
                  if (aCreated == null && bCreated == null) return 0;
                  if (aCreated == null) return 1;
                  if (bCreated == null) return -1;
                  return aCreated.compareTo(bCreated);
                });
          final rejectionReason = rejectedApproval.isEmpty
              ? null
              : rejectedApproval.first['rejection_reason']?.toString().trim();
          final rejectingOffice = rejectedApproval.isEmpty
              ? null
              : rejectedApproval.first['approver_user_id'] != null
              ? await _getUserDisplayName(
                  rejectedApproval.first['approver_user_id'] as int,
                )
              : await _getOfficeNameById(
                  rejectedApproval.first['office_id'] as int?,
                );
          final databaseTimestamps = <DateTime>[];
          for (final rawTimestamp in [
            res['updated_at'],
            res['created_at'],
            ...?approvalRowsByReservation[reservationId]?.expand(
              (approval) => [
                approval['updated_at'],
                approval['approved_at'],
                approval['created_at'],
              ],
            ),
          ]) {
            final parsed = DateTime.tryParse(rawTimestamp?.toString() ?? '');
            if (parsed != null) databaseTimestamps.add(parsed);
          }
          databaseTimestamps.sort();

          if (!includeDetails) {
            return ReservationRecord(
              id: reservationId.toString(),
              userId: userId,
              reservationTitle:
                  res['activity_name'] as String? ?? 'Reservation Request',
              roomName: 'Reservation',
              reservationType: 'Reservation',
              reservationStatus: effectiveStatus,
              date: date,
              reservationTime: reservationTime,
              lastUpdatedAt: databaseTimestamps.isEmpty
                  ? null
                  : databaseTimestamps.last,
            );
          }

          final roomNameFuture = _fetchReservationRoomName(reservationId);
          final eventDetailsFuture = _fetchInstitutionalEventHistoryDetails(
            reservationId,
          );
          final timelineFuture = _buildApprovalTimeline(
            reservationId,
            date,
            approvalRowsByReservation[reservationId] ?? const [],
            submittedAt: DateTime.tryParse(res['created_at']?.toString() ?? ''),
            requesterIsDean: requesterIsDean,
          );
          final reservedItemsFuture = _fetchReservationItemNames(reservationId);
          final detailCheckFuture = _client
              .from('reservation_details')
              .select('reservation_items_id')
              .eq('reservation_id', reservationId)
              .limit(1)
              .maybeSingle();

          final results = await Future.wait([
            roomNameFuture,
            eventDetailsFuture,
            timelineFuture,
            reservedItemsFuture,
            detailCheckFuture,
          ]);

          final eventDetails = results[1] as Map<String, dynamic>?;
          final roomName =
              eventDetails?['roomName'] as String? ??
              results[0] as String? ??
              'Reserved Room';
          final timeline = results[2] as List<ReservationTimelineEntry>? ?? [];
          final reservedItems =
              eventDetails?['reservedItems'] as List<String>? ??
              results[3] as List<String>? ??
              [];
          final detailCheck = results[4] as Map<String, dynamic>?;

          var reservationType = eventDetails == null
              ? 'Venue Reservation'
              : 'Institutional Event Reservation';
          if (eventDetails == null &&
              detailCheck != null &&
              detailCheck['reservation_items_id'] != null) {
            reservationType = 'Item Reservation';
          }

          return ReservationRecord(
            id: reservationId.toString(),
            userId: userId,
            reservationTitle:
                res['activity_name'] as String? ?? 'Reservation Request',
            roomName: roomName,
            reservationType: reservationType,
            reservationStatus: effectiveStatus,
            date: date,
            reservationTime: reservationTime,
            lastUpdatedAt: databaseTimestamps.isEmpty
                ? null
                : databaseTimestamps.last,
            timeline: timeline,
            reservedItems: reservedItems,
            eventVenues:
                eventDetails?['eventVenues'] as List<ReservationVenueDetail>? ??
                const [],
            rejectionReason:
                _isRejectedStatus(effectiveStatus) &&
                    rejectionReason?.isNotEmpty == true
                ? rejectionReason
                : null,
            rejectedBy:
                _isRejectedStatus(effectiveStatus) &&
                    rejectingOffice?.isNotEmpty == true
                ? approvalOfficeLabel(rejectingOffice!)
                : null,
          );
        } catch (e) {
          print('Error processing reservation entry: $e');
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      final records = results.whereType<ReservationRecord>().toList();
      return records;
    } catch (e) {
      print('Error fetching user reservations: $e');
      return [];
    }
  }

  /// Status and waiting-office snapshot for notifications.
  /// Skips room, item, and approval-chain lookups.
  Future<List<ReservationRecord>> getReservationStatusSnapshots(
    int userId,
  ) async {
    try {
      final reservationsResponse = await _client
          .from('reservations')
          .select(
            'reservation_id, activity_name, overall_status, created_at, updated_at, Date_of_Activity, Start_of_activity, End_of_Activity',
          )
          .eq('user_id', userId)
          .order('Date_of_Activity', ascending: false);

      if (reservationsResponse == null) {
        return [];
      }

      final resList = reservationsResponse as List;
      final reservationIds = resList
          .map((res) => res['reservation_id'] as int?)
          .whereType<int>()
          .toList();
      final approvalsResponse = reservationIds.isEmpty
          ? const <Map<String, dynamic>>[]
          : await _client
                .from('reservation_approvals')
                .select(
                  'reservation_id, office_id, approver_user_id, approval_stage, '
                  'status, approved_at, created_at, updated_at, rejection_reason, '
                  'reconsideration_message, requester_condition_response',
                )
                .in_('reservation_id', reservationIds);
      final approvalRowsByReservation = <int, List<Map<String, dynamic>>>{};
      if (approvalsResponse != null) {
        for (final approval in approvalsResponse as List) {
          final reservationId = approval['reservation_id'] as int?;
          if (reservationId == null) continue;
          approvalRowsByReservation
              .putIfAbsent(reservationId, () => [])
              .add(Map<String, dynamic>.from(approval as Map<String, dynamic>));
        }
      }

      final officeIds = approvalRowsByReservation.values
          .expand((rows) => rows.map((row) => row['office_id'] as int?))
          .whereType<int>()
          .toSet();
      final officeNames = await _officeNamesById(officeIds);
      final facultyUserIds = approvalRowsByReservation.values
          .expand((rows) => rows.map((row) => row['approver_user_id'] as int?))
          .whereType<int>()
          .toSet();
      final facultyNames = await _userNamesById(facultyUserIds);

      return resList.where((res) => res['reservation_id'] is int).map((res) {
        final reservationId = res['reservation_id'] as int;
        final date = DateTime.parse(res['Date_of_Activity'] as String);
        final startTime = DateTime.parse(res['Start_of_activity'] as String);
        final endTime = DateTime.parse(res['End_of_Activity'] as String);
        final approvalRows =
            List<Map<String, dynamic>>.from(
              approvalRowsByReservation[reservationId] ?? const [],
            )..sort((a, b) {
              final aCreated = DateTime.tryParse(
                a['created_at']?.toString() ?? '',
              );
              final bCreated = DateTime.tryParse(
                b['created_at']?.toString() ?? '',
              );
              if (aCreated == null && bCreated == null) return 0;
              if (aCreated == null) return 1;
              if (bCreated == null) return -1;
              return aCreated.compareTo(bCreated);
            });
        final effectiveStatus = resolveApprovalStatusFromRows(
          overallStatus:
              (res['overall_status'] as String?) ?? 'Pending Approval',
          approvalRows: approvalRows,
        );
        final rejectedApproval = approvalRows.where((approval) {
          final status = (approval['status'] as String? ?? '')
              .trim()
              .toLowerCase();
          return status == 'rejected' || status == 'denied';
        }).toList();
        final rejectionReason = rejectedApproval.isEmpty
            ? null
            : rejectedApproval.first['rejection_reason']?.toString().trim();
        final rejectedByUserId = rejectedApproval.isEmpty
            ? null
            : rejectedApproval.first['approver_user_id'] as int?;
        final rejectingOfficeId = rejectedApproval.isEmpty
            ? null
            : rejectedApproval.first['office_id'] as int?;
        final rejectingOffice = rejectedByUserId != null
            ? facultyNames[rejectedByUserId]
            : rejectingOfficeId == null
            ? null
            : officeNames[rejectingOfficeId];
        final databaseTimestamps = <DateTime>[];
        for (final rawTimestamp in [
          res['updated_at'],
          res['created_at'],
          ...approvalRows.expand(
            (approval) => [
              approval['updated_at'],
              approval['approved_at'],
              approval['created_at'],
            ],
          ),
        ]) {
          final parsed = DateTime.tryParse(rawTimestamp?.toString() ?? '');
          if (parsed != null) databaseTimestamps.add(parsed);
        }
        databaseTimestamps.sort();

        final submittedAt =
            DateTime.tryParse(res['created_at']?.toString() ?? '') ?? date;
        final timeline = <ReservationTimelineEntry>[
          ReservationTimelineEntry(
            title: 'Request Submitted',
            status: 'Completed',
            date: submittedAt,
            timestamp: _formatTimestamp(submittedAt),
            description: 'Your reservation request was submitted successfully.',
          ),
          for (final row in approvalRows)
            _timelineEntryForApprovalRow(row, date, officeNames, facultyNames),
        ];

        return ReservationRecord(
          id: reservationId.toString(),
          userId: userId,
          reservationTitle:
              res['activity_name'] as String? ?? 'Reservation Request',
          roomName: 'Reservation',
          reservationType: 'Reservation',
          reservationStatus: effectiveStatus,
          date: date,
          reservationTime:
              '${_formatDateTime(startTime)} - ${_formatDateTime(endTime)}',
          lastUpdatedAt: databaseTimestamps.isEmpty
              ? null
              : databaseTimestamps.last,
          timeline: timeline,
          rejectionReason:
              _isRejectedStatus(effectiveStatus) &&
                  rejectionReason?.isNotEmpty == true
              ? rejectionReason
              : null,
          rejectedBy:
              _isRejectedStatus(effectiveStatus) &&
                  rejectingOffice?.isNotEmpty == true
              ? approvalOfficeLabel(rejectingOffice!)
              : null,
        );
      }).toList();
    } catch (e) {
      print('Error fetching reservation status snapshots: $e');
      return [];
    }
  }

  Future<Map<int, String>> _officeNamesById(Set<int> officeIds) async {
    if (officeIds.isEmpty) return {};
    try {
      final response = await _client
          .from('offices')
          .select('office_id, department_name')
          .in_('office_id', officeIds.toList());
      final names = <int, String>{};
      for (final row in response as List) {
        final officeId = row['office_id'] as int?;
        final name = row['department_name'] as String?;
        if (officeId == null || name == null || name.trim().isEmpty) continue;
        names[officeId] = name;
        _officeByIdCache[officeId] = Map<String, dynamic>.from(
          row as Map<String, dynamic>,
        );
      }
      return names;
    } catch (e) {
      print('Error fetching office names: $e');
      return {};
    }
  }

  Future<Map<int, String>> _userNamesById(Set<int> userIds) async {
    if (userIds.isEmpty) return {};
    final response = await _client
        .from('users')
        .select('user_id, full_name, first_name, last_name')
        .in_('user_id', userIds.toList());
    final names = <int, String>{};
    for (final row in response as List) {
      final profile = Map<String, dynamic>.from(row as Map);
      final userId = profile['user_id'] as int?;
      if (userId == null) continue;
      final fullName = (profile['full_name'] as String?)?.trim();
      final name = fullName?.isNotEmpty == true
          ? fullName!
          : [profile['first_name'], profile['last_name']]
                .whereType<String>()
                .where((part) => part.trim().isNotEmpty)
                .join(' ');
      if (name.isNotEmpty) names[userId] = name;
    }
    return names;
  }

  ReservationTimelineEntry _timelineEntryForApprovalRow(
    Map<String, dynamic> row,
    DateTime date,
    Map<int, String> officeNames,
    Map<int, String> facultyNames,
  ) {
    final officeId = row['office_id'] as int?;
    final officeName = officeId == null ? null : officeNames[officeId];
    final facultyUserId = row['approver_user_id'] as int?;
    final facultyName = facultyUserId == null
        ? null
        : facultyNames[facultyUserId];
    final title = facultyUserId != null
        ? 'Faculty Approval${facultyName == null ? '' : ' - $facultyName'}'
        : approvalOfficeLabel(
            officeName == null || officeName.trim().isEmpty
                ? 'Office'
                : officeName,
          );
    final rowStatus = (row['status'] as String? ?? '').trim().toLowerCase();
    final String status;
    if (rowStatus.contains('returned')) {
      status = 'Returned';
    } else if (rowStatus == 'approved' || rowStatus == 'accepted') {
      status = 'Approved';
    } else if (rowStatus == 'completed' || rowStatus == 'complete') {
      status = 'Completed';
    } else if (rowStatus == 'rejected' || rowStatus == 'denied') {
      status = 'Rejected';
    } else if (rowStatus == 'cancelled' || rowStatus == 'canceled') {
      status = 'Cancelled';
    } else {
      status = 'Pending';
    }
    final timestamp = status == 'Pending'
        ? 'Pending'
        : _formatStoredApprovalTime(row, date);
    final description = switch (status) {
      'Approved' => 'Your reservation has been approved by $title.',
      'Completed' => 'This reservation has been completed.',
      'Returned' =>
        'This reservation has been returned and the item units are available again.',
      'Rejected' =>
        'Your reservation was rejected by $title'
            '${(row['rejection_reason'] as String?)?.trim().isNotEmpty == true ? ': ${row['rejection_reason']}' : '.'}',
      'Cancelled' => 'This reservation was cancelled.',
      _ => 'Waiting for approval from $title.',
    };
    return ReservationTimelineEntry(
      title: title,
      status: status,
      date: date,
      timestamp: timestamp,
      description: description,
    );
  }

  Future<String?> _fetchReservationRoomName(int reservationId) async {
    try {
      final detailResponse = await _client
          .from('reservation_details')
          .select('reservation_rooms_id')
          .eq('reservation_id', reservationId)
          .limit(1)
          .maybeSingle();

      final roomReservationId = detailResponse?['reservation_rooms_id'] as int?;
      if (roomReservationId == null) {
        // Might be an item reservation — check for reservation_items_id
        final itemDetail = await _client
            .from('reservation_details')
            .select('reservation_items_id')
            .eq('reservation_id', reservationId)
            .limit(1)
            .maybeSingle();
        if (itemDetail != null && itemDetail['reservation_items_id'] != null) {
          return 'Item Reservation';
        }
        return 'Room Reservation';
      }

      final roomReservationResponse = await _client
          .from('reservation_rooms')
          .select('room_id')
          .eq('reservation_rooms_id', roomReservationId)
          .limit(1)
          .maybeSingle();
      final roomId = roomReservationResponse?['room_id'] as int?;
      if (roomId == null) {
        return 'Room Reservation';
      }

      final roomResponse = await _client
          .from('rooms')
          .select('room_number, room_type')
          .eq('room_id', roomId)
          .limit(1)
          .maybeSingle();
      if (roomResponse == null) {
        return 'Room Reservation';
      }

      final roomNumber = roomResponse['room_number'] as String?;
      final roomType = roomResponse['room_type'] as String?;
      if (roomNumber != null && roomNumber.isNotEmpty) {
        return roomNumber;
      }
      if (roomType != null && roomType.isNotEmpty) {
        return roomType;
      }
      return 'Room Reservation';
    } catch (_) {
      return 'Room Reservation';
    }
  }

  Future<bool> _institutionalEventContainsGym(int reservationId) async {
    final eventVenues = await _client
        .from('institutional_event_venues')
        .select('room_id')
        .eq('reservation_id', reservationId);
    final roomIds = (eventVenues as List)
        .map((row) => row['room_id'] as int)
        .toSet()
        .toList();
    if (roomIds.isEmpty) return false;
    final rooms = await _client
        .from('rooms')
        .select('room_id, room_type')
        .in_('room_id', roomIds);
    return (rooms as List).any(
      (room) => (room['room_type'] as String? ?? '').toLowerCase() == 'gym',
    );
  }

  Future<Map<String, dynamic>?> _fetchInstitutionalEventHistoryDetails(
    int reservationId,
  ) async {
    final eventRequest = await _client
        .from('institutional_event_requests')
        .select('reservation_id')
        .eq('reservation_id', reservationId)
        .maybeSingle();
    if (eventRequest == null) return null;

    final venueRows =
        (await _client
                    .from('institutional_event_venues')
                    .select(
                      'event_venue_id, room_id, start_time, end_time, status, removal_reason',
                    )
                    .eq('reservation_id', reservationId)
                    .order('start_time')
                as List)
            .cast<Map<String, dynamic>>();
    final roomIds = venueRows
        .map((venue) => venue['room_id'] as int)
        .toSet()
        .toList();
    final rooms = roomIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _client
                      .from('rooms')
                      .select('room_id, room_number, room_type')
                      .in_('room_id', roomIds)
                  as List)
              .cast<Map<String, dynamic>>();
    final roomsById = {for (final room in rooms) room['room_id'] as int: room};
    final venueNamesById = <int, String>{};
    final eventVenues = <int, ReservationVenueDetail>{};
    final venueNames = <String>[];
    for (final venue in venueRows) {
      final venueId = venue['event_venue_id'] as int;
      final room = roomsById[venue['room_id'] as int];
      final name = room == null
          ? 'Venue ${venue['room_id']}'
          : _roomDisplayName(room);
      venueNamesById[venueId] = name;
      if (!venueNames.contains(name)) venueNames.add(name);
      eventVenues[venueId] = ReservationVenueDetail(
        name: name,
        startTime: DateTime.parse(venue['start_time'].toString()),
        endTime: DateTime.parse(venue['end_time'].toString()),
        status: venue['status'] as String? ?? 'included',
        removalReason: venue['removal_reason'] as String?,
      );
    }

    final equipmentRows =
        (await _client
                    .from('institutional_event_equipment')
                    .select(
                      'event_equipment_id, event_venue_id, reservation_items_id, status, removal_reason',
                    )
                    .eq('reservation_id', reservationId)
                as List)
            .cast<Map<String, dynamic>>();
    final itemLinkIds = equipmentRows
        .map((equipment) => equipment['reservation_items_id'] as int)
        .toSet()
        .toList();
    final itemLinks = itemLinkIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _client
                      .from('reservation_items')
                      .select('reservation_items_id, item_id')
                      .in_('reservation_items_id', itemLinkIds)
                  as List)
              .cast<Map<String, dynamic>>();
    final itemIds = itemLinks
        .map((link) => link['item_id'] as int)
        .toSet()
        .toList();
    final items = itemIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _client
                      .from('items')
                      .select('item_id, item_name')
                      .in_('item_id', itemIds)
                  as List)
              .cast<Map<String, dynamic>>();
    final itemNameById = {
      for (final item in items)
        item['item_id'] as int: item['item_name'] as String,
    };
    final itemIdByLinkId = {
      for (final link in itemLinks)
        link['reservation_items_id'] as int: link['item_id'] as int,
    };
    final details =
        (await _client
                    .from('reservation_details')
                    .select('reservation_items_id, quantity')
                    .eq('reservation_id', reservationId)
                as List)
            .cast<Map<String, dynamic>>();
    final quantityByLinkId = {
      for (final detail in details)
        if (detail['reservation_items_id'] != null)
          detail['reservation_items_id'] as int:
              detail['quantity'] as int? ?? 1,
    };
    final equipmentLabels = <String>[];
    for (final equipment in equipmentRows) {
      final linkId = equipment['reservation_items_id'] as int;
      final itemId = itemIdByLinkId[linkId];
      final name = itemId == null
          ? 'Equipment'
          : itemNameById[itemId] ?? 'Item $itemId';
      final quantity = quantityByLinkId[linkId] ?? 1;
      final venueName =
          venueNamesById[equipment['event_venue_id'] as int] ?? 'venue';
      final status = equipment['status'] as String? ?? 'included';
      final removedLabel = status == 'removed' ? ' (removed)' : '';
      equipmentLabels.add(
        '$name (quantity: $quantity, $venueName)$removedLabel',
      );
      final venueId = equipment['event_venue_id'] as int;
      final venue = eventVenues[venueId];
      if (venue != null) {
        eventVenues[venueId] = ReservationVenueDetail(
          name: venue.name,
          startTime: venue.startTime,
          endTime: venue.endTime,
          status: venue.status,
          removalReason: venue.removalReason,
          equipment: [
            ...venue.equipment,
            ReservationEquipmentDetail(
              name: name,
              quantity: quantity,
              status: status,
              removalReason: equipment['removal_reason'] as String?,
            ),
          ],
        );
      }
    }

    return {
      'roomName': _compactVenueSummary(venueNames),
      'reservedItems': equipmentLabels,
      'eventVenues': eventVenues.values.toList(),
    };
  }

  String _roomDisplayName(Map<String, dynamic> room) {
    final type = (room['room_type'] as String? ?? '').trim();
    final number = (room['room_number'] as String? ?? '').trim();
    if (number.isEmpty || number.toLowerCase() == type.toLowerCase()) {
      return type.isEmpty ? 'Venue' : type;
    }
    return '$type $number'.trim();
  }

  String _compactVenueSummary(List<String> venueNames) {
    if (venueNames.isEmpty) return 'Institutional event';
    if (venueNames.length == 1) return venueNames.first;
    if (venueNames.length == 2) {
      return '${venueNames[0]}, ${venueNames[1]}';
    }
    return '${venueNames[0]}, ${venueNames[1]} +${venueNames.length - 2} more';
  }

  /// Fetch item names reserved under a reservation (if any)
  Future<List<String>> _fetchReservationItemNames(int reservationId) async {
    final names = <String>[];
    try {
      final details = await _client
          .from('reservation_details')
          .select('reservation_items_id')
          .eq('reservation_id', reservationId);
      if (details == null) return names;
      final itemNames = await Future.wait(
        (details as List).map((det) async {
          final reservationItemsId = det['reservation_items_id'] as int?;
          if (reservationItemsId == null) return null;

          final itemLink = await _client
              .from('reservation_items')
              .select('item_id')
              .eq('reservation_items_id', reservationItemsId)
              .maybeSingle();
          final itemId = itemLink?['item_id'] as int?;
          if (itemId == null) return null;

          final itemRow = await _client
              .from('items')
              .select('item_name')
              .eq('item_id', itemId)
              .maybeSingle();
          final itemName = itemRow?['item_name'] as String?;
          return itemName != null && itemName.isNotEmpty ? itemName : null;
        }),
      );
      names.addAll(itemNames.whereType<String>());
    } catch (e) {
      print('Error fetching reservation item names: $e');
    }
    return names;
  }

  String _formatDateTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : (dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour);
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  Future<List<String>> _getReservationItemOwnerNames(int reservationId) async {
    final itemOwners = <String>{};
    try {
      final details = await _client
          .from('reservation_details')
          .select('reservation_items_id')
          .eq('reservation_id', reservationId);
      if (details == null) return [];

      for (final det in details as List) {
        final reservationItemsId = det['reservation_items_id'] as int?;
        if (reservationItemsId == null) continue;

        final itemLink = await _client
            .from('reservation_items')
            .select('item_id')
            .eq('reservation_items_id', reservationItemsId)
            .maybeSingle();
        final itemId = itemLink?['item_id'] as int?;
        if (itemId == null) continue;

        final item = await getItemDetails(itemId);
        if (item != null && item.ownerId != null) {
          final owner = await getItemOwner(item.ownerId!);
          if (owner != null) {
            final affiliation = (owner['department_affiliation'] as String?)
                ?.trim()
                .toUpperCase();
            final ownerName = owner['owner_name'] as String?;
            if (affiliation != 'PFO' && ownerName != null) {
              itemOwners.add(ownerName);
            }
          }
        }
      }
    } catch (e) {
      print('Error fetching reservation item owner names: $e');
    }
    return itemOwners.toList();
  }

  String _formatTimestamp(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : (date.hour > 12 ? date.hour - 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${date.month}/${date.day}/${date.year} $hour:$minute $period';
  }

  /// The time an office actually approved, kept as the Manila clock stored
  /// in the database. approved_at is that moment; updated_at can be UTC.
  String _formatStoredApprovalTime(
    Map<String, dynamic> row,
    DateTime fallback,
  ) {
    final stored =
        DateTime.tryParse(row['approved_at']?.toString() ?? '') ??
        DateTime.tryParse(row['updated_at']?.toString() ?? '') ??
        DateTime.tryParse(row['created_at']?.toString() ?? '');
    return _formatTimestamp(stored ?? fallback);
  }

  DateTime buildApprovalTimestampForStep(int step, {DateTime? baseTime}) {
    final base = (baseTime ?? DateTime.now()).toUtc();
    return base.add(Duration(milliseconds: step));
  }

  static List<Map<String, dynamic>> sortApprovalEntriesForTimeline(
    List<Map<String, dynamic>> approvals, {
    int? itemOwnerOfficeId,
    int? generalEducationOfficeId,
  }) {
    return approvals.asMap().entries.map((entry) {
      final approval = Map<String, dynamic>.from(entry.value);
      final officeId = approval['office_id'] as int?;
      final officeName =
          (approval['office_name'] as String?)?.toLowerCase() ?? '';

      try {
        final createdRaw = approval['created_at'] as String?;
        if (createdRaw != null && createdRaw.isNotEmpty) {
          final createdAt = DateTime.parse(createdRaw).toUtc();
          approval['__created_at_ts'] = createdAt.millisecondsSinceEpoch;
        } else {
          approval['__created_at_ts'] = null;
        }
      } catch (_) {
        approval['__created_at_ts'] = null;
      }

      int rank;
      if (generalEducationOfficeId != null &&
          officeId == generalEducationOfficeId) {
        rank = -2;
      } else if (officeName.contains('general education')) {
        rank = -2;
      } else if (itemOwnerOfficeId != null && officeId == itemOwnerOfficeId) {
        rank = 0;
      } else if (officeName.contains('item owner')) {
        rank = 0;
      } else if (officeName.isNotEmpty &&
          !officeName.contains('program chair') &&
          !officeName.contains('sdao') &&
          !officeName.contains('do') &&
          !officeName.contains('security') &&
          !officeName.contains('physical facilities') &&
          !officeName.contains('general education')) {
        rank = 0;
      } else if (officeName.contains('program chair')) {
        rank = 1;
      } else if (officeName.contains('sdao')) {
        rank = 2;
      } else if (officeName.contains('do')) {
        rank = 3;
      } else if (officeName.contains('security')) {
        rank = 4;
      } else if (officeName.contains('physical facilities')) {
        rank = 5;
      } else {
        rank = 999;
      }

      approval['__timeline_rank'] = rank;
      approval['__original_index'] = entry.key;
      return approval;
    }).toList()..sort((a, b) {
      final rankA = a['__timeline_rank'] as int;
      final rankB = b['__timeline_rank'] as int;
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      final aTs = a['__created_at_ts'] as int?;
      final bTs = b['__created_at_ts'] as int?;
      if (aTs != null && bTs != null) {
        final cmp = aTs.compareTo(bTs);
        if (cmp != 0) return cmp;
      } else if (aTs != null) {
        return -1;
      } else if (bTs != null) {
        return 1;
      }

      final indexA = a['__original_index'] as int;
      final indexB = b['__original_index'] as int;
      return indexA.compareTo(indexB);
    });
  }

  // MARK: - Approval Workflow

  static String normalizeRoomType(String? roomType) {
    return (roomType ?? '')
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  static bool isGymRoomType(String? roomType) {
    return normalizeRoomType(roomType) == 'gym';
  }

  /// Calculate the approval chain based on room type and items reserved
  Future<ApprovalChain> calculateApprovalChain({
    required String roomType,
    required List<int>? itemIds,
  }) async {
    try {
      final officeTitles = <String>[];
      final officeIds = <int>[];
      final itemOwners = <String>[];
      final normalizedRoomType = normalizeRoomType(roomType);
      final standardOffices = [
        'Program Chair',
        'SDAO',
        'DO',
        'Security',
        'Physical Facilities',
      ];

      final Future<List<String?>> itemOwnerNamesFuture = Future.wait<String?>(
        (itemIds ?? const <int>[]).map((itemId) async {
          final itemResponse = await _client
              .from('items')
              .select('owner_id')
              .eq('item_id', itemId)
              .maybeSingle();
          final ownerId = itemResponse?['owner_id'] as int?;
          if (ownerId == null) return null;

          final owner = await getItemOwner(ownerId);
          if (owner == null) return null;

          final affiliation = (owner['department_affiliation'] as String?)
              ?.trim()
              .toUpperCase();
          final ownerName = owner['owner_name'] as String?;
          if (ownerName == null ||
              affiliation == 'PFO' ||
              affiliation == 'PHYSICAL FACILITIES') {
            return null;
          }
          return ownerName;
        }),
      );
      final officeNames = [
        'Item Owner',
        'General Education',
        ...standardOffices,
      ];
      final Future<List<MapEntry<String, int?>>> officeIdsFuture =
          Future.wait<MapEntry<String, int?>>(
            officeNames.map(
              (name) async => MapEntry(name, await _getOfficeIdByName(name)),
            ),
          );
      final itemOwnerNameResults = await itemOwnerNamesFuture;
      final officeIdResults = await officeIdsFuture;
      for (final ownerName in itemOwnerNameResults) {
        if (ownerName != null && !itemOwners.contains(ownerName)) {
          itemOwners.add(ownerName);
        }
      }
      final officeIdsByName = Map<String, int?>.fromEntries(officeIdResults);
      final itemOwnerOfficeId = officeIdsByName['Item Owner'];
      final hasItems = itemIds != null && itemIds.isNotEmpty;

      /// Helper to safely add an office with its ID to both lists
      Future<void> addOfficeToChain(String officeName) async {
        final officeId = officeIdsByName[officeName];
        if (officeId != null) {
          officeTitles.add(officeName);
          officeIds.add(officeId);
        } else {
          // If office not found, log and skip to keep lists in sync
          print('Warning: office not found: $officeName');
        }
      }

      /// Helper to add item owner to the chain
      Future<void> addItemOwnersToChain() async {
        if (itemOwners.isNotEmpty && itemOwnerOfficeId != null) {
          for (final ownerName in itemOwners) {
            officeTitles.add(ownerName);
            officeIds.add(itemOwnerOfficeId);
          }
        }
      }

      if (normalizedRoomType == 'gym') {
        // Gym: General Education → Item Owner? → Program Chair → SDAO → DO → Security → Physical Facilities
        await addOfficeToChain('General Education');
        if (itemOwners.isNotEmpty) {
          await addItemOwnersToChain();
        }
        await addOfficeToChain('Program Chair');
        for (int i = 1; i < standardOffices.length; i++) {
          await addOfficeToChain(standardOffices[i]);
        }
      } else if (normalizedRoomType == 'classroom') {
        // Classroom: Item Owner? → Program Chair → SDAO → DO → Security → Physical Facilities
        if (itemOwners.isNotEmpty) {
          await addItemOwnersToChain();
        }
        await addOfficeToChain('Program Chair');
        for (int i = 1; i < standardOffices.length; i++) {
          await addOfficeToChain(standardOffices[i]);
        }
      } else if (normalizedRoomType == 'avr' ||
          normalizedRoomType == 'lobby' ||
          normalizedRoomType == 'student lounge') {
        // AVR/Lobby/Student Lounge: Item Owner? → Program Chair → SDAO → DO → Security → Physical Facilities
        if (itemOwners.isNotEmpty) {
          await addItemOwnersToChain();
        }
        await addOfficeToChain('Program Chair');
        for (int i = 1; i < standardOffices.length; i++) {
          await addOfficeToChain(standardOffices[i]);
        }
      } else if (hasItems) {
        // Item only: Item Owner → Program Chair → SDAO → DO → Security → Physical Facilities
        await addItemOwnersToChain();
        await addOfficeToChain('Program Chair');
        for (int i = 1; i < standardOffices.length; i++) {
          await addOfficeToChain(standardOffices[i]);
        }
      } else {
        // No items, default room: Program Chair → SDAO → DO → Security → Physical Facilities
        for (final office in standardOffices) {
          await addOfficeToChain(office);
        }
      }

      return ApprovalChain(offices: officeTitles, officeIds: officeIds);
    } catch (e) {
      print('Error calculating approval chain: $e');
      return ApprovalChain(offices: [], officeIds: []);
    }
  }

  /// Get office ID by name
  Future<Map<String, dynamic>?> _getOfficeByName(String departmentName) async {
    final cacheKey = departmentName.trim().toLowerCase();
    if (_officeByNameCache.containsKey(cacheKey)) {
      return _officeByNameCache[cacheKey];
    }

    final pendingRequest = _officeByNameRequests[cacheKey];
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _fetchOfficeByName(departmentName, cacheKey);
    _officeByNameRequests[cacheKey] = request;
    try {
      return await request;
    } finally {
      if (identical(_officeByNameRequests[cacheKey], request)) {
        _officeByNameRequests.remove(cacheKey);
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchOfficeByName(
    String departmentName,
    String cacheKey,
  ) async {
    try {
      final response = await _client
          .from('offices')
          .select()
          .ilike('department_name', departmentName)
          .maybeSingle();

      final office = response as Map<String, dynamic>?;
      _officeByNameCache[cacheKey] = office;
      return office;
    } catch (e) {
      print('Error fetching office: $e');
      _officeByNameCache[cacheKey] = null;
      return null;
    }
  }

  Future<int?> _getOfficeIdByName(String departmentName) async {
    final office = await _getOfficeByName(departmentName);
    return office == null ? null : office['office_id'] as int?;
  }

  /// Get item owner record
  Future<Map<String, dynamic>?> getItemOwner(int ownerId) async {
    try {
      final response = await _client
          .from('item_owners')
          .select('owner_name, department_affiliation')
          .eq('owner_id', ownerId)
          .maybeSingle();

      return response as Map<String, dynamic>?;
    } catch (e) {
      print('Error fetching item owner: $e');
      return null;
    }
  }

  /// Get only the item owner name
  Future<String?> getItemOwnerName(int ownerId) async {
    final owner = await getItemOwner(ownerId);
    return owner?['owner_name'] as String?;
  }

  Future<bool> submitIssueReport({
    int? reservationId,
    required String description,
    String? imageName,
    String? imageBase64,
    List<String>? reportedItems,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) {
      debugPrint(
        '[ReservationService] Cannot submit issue report without a session.',
      );
      return false;
    }

    final hasImageName = imageName != null && imageName.isNotEmpty;
    final hasImageBytes = imageBase64 != null && imageBase64.isNotEmpty;
    if (hasImageName != hasImageBytes) {
      debugPrint('[ReservationService] Issue report image data is incomplete.');
      return false;
    }

    try {
      final response = await _client.functions.invoke(
        'submit_issue_report',
        body: {
          'description': description,
          if (reservationId != null) 'reservation_id': reservationId,
          if (hasImageName) 'image_name': imageName,
          if (hasImageBytes) 'image_base64': imageBase64,
          if (reportedItems != null && reportedItems.isNotEmpty)
            'reported_items': reportedItems,
        },
      );

      final status = response.status;
      if (status == null || status < 200 || status >= 300) {
        debugPrint(
          '[ReservationService] Issue report function returned ${response.status}.',
        );
        return false;
      }

      final responseBody = response.data;
      return responseBody is Map && responseBody['ok'] == true;
    } catch (e) {
      debugPrint('[ReservationService] Issue report submission failed: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getOfficeById(int officeId) async {
    if (_officeByIdCache.containsKey(officeId)) {
      return _officeByIdCache[officeId];
    }

    final pendingRequest = _officeByIdRequests[officeId];
    if (pendingRequest != null) {
      return pendingRequest;
    }

    final request = _fetchOfficeById(officeId);
    _officeByIdRequests[officeId] = request;
    try {
      return await request;
    } finally {
      if (identical(_officeByIdRequests[officeId], request)) {
        _officeByIdRequests.remove(officeId);
      }
    }
  }

  Future<Map<String, dynamic>?> _fetchOfficeById(int officeId) async {
    try {
      final response = await _client
          .from('offices')
          .select('department_name')
          .eq('office_id', officeId)
          .maybeSingle();
      final office = response as Map<String, dynamic>?;
      _officeByIdCache[officeId] = office;
      return office;
    } catch (e) {
      print('Error fetching office by id: $e');
      _officeByIdCache[officeId] = null;
      return null;
    }
  }

  Future<String?> _getOfficeNameById(int? officeId) async {
    if (officeId == null) return null;
    final office = await _getOfficeById(officeId);
    return office?['department_name'] as String?;
  }

  Future<String?> _getUserDisplayName(int userId) async {
    final profile = await _client
        .from('users')
        .select('full_name, first_name, last_name')
        .eq('user_id', userId)
        .maybeSingle();
    final fullName = (profile?['full_name'] as String?)?.trim();
    if (fullName?.isNotEmpty == true) return fullName;
    final name = [
      profile?['first_name'],
      profile?['last_name'],
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return name.isEmpty ? null : name;
  }

  Future<List<ReservationTimelineEntry>> _buildApprovalTimeline(
    int reservationId,
    DateTime date,
    List<Map<String, dynamic>> approvals, {
    DateTime? submittedAt,
    bool requesterIsDean = false,
  }) async {
    try {
      // Use canonical chain to force UI order, but read DB rows for status/timestamps.
      final prerequisites = await Future.wait([
        _getReservationRoomType(reservationId),
        _getReservationItemIds(reservationId),
        _institutionalEventContainsGym(reservationId),
      ]);
      final roomType = prerequisites[2] == true
          ? 'Gym'
          : prerequisites[0] as String?;
      final itemIds = prerequisites[1] as List<int>;
      final approvalChain = await calculateApprovalChain(
        roomType: roomType ?? '',
        itemIds: itemIds.isEmpty ? null : itemIds,
      );
      final allApprovalRows = List<Map<String, dynamic>>.from(approvals);
      final facultyApprovalRows = allApprovalRows
          .where((row) => row['approver_user_id'] != null)
          .toList();
      final facultyApproval = facultyApprovalRows.isEmpty
          ? null
          : facultyApprovalRows.first;
      final approvalsResponse =
          allApprovalRows
              .where((row) => row['approver_user_id'] == null)
              .toList()
            ..sort((a, b) {
              final aCreated = DateTime.tryParse(
                a['created_at']?.toString() ?? '',
              );
              final bCreated = DateTime.tryParse(
                b['created_at']?.toString() ?? '',
              );
              if (aCreated == null && bCreated == null) return 0;
              if (aCreated == null) return 1;
              if (bCreated == null) return -1;
              return aCreated.compareTo(bCreated);
            });

      final rawApprovals = <Map<String, dynamic>>[];
      final augmentedApprovals = await Future.wait(
        approvalsResponse.map((a) async {
          final row = Map<String, dynamic>.from(a);
          final officeId = row['office_id'] as int?;
          final office = officeId == null
              ? null
              : await _getOfficeById(officeId);
          row['office_name'] = row['approval_stage'] == 'program_chair'
              ? 'Program Chair'
              : office?['department_name'] as String?;
          return row;
        }),
      );
      rawApprovals.addAll(augmentedApprovals);

      if (kDebugMode) {
        print(
          'DEBUG: reservation $reservationId approvalChain offices: ${jsonEncode(approvalChain.offices)}',
        );
        print(
          'DEBUG: reservation $reservationId approvalChain officeIds: ${jsonEncode(approvalChain.officeIds)}',
        );
        print(
          'DEBUG: reservation $reservationId rawApprovals: ${jsonEncode(rawApprovals.map((r) => {'office_id': r['office_id'], 'status': r['status'], 'created_at': r['created_at'], 'updated_at': r['updated_at']}).toList())}',
        );
      }

      final submitted = submittedAt ?? date;
      final entries = <ReservationTimelineEntry>[];
      entries.add(
        ReservationTimelineEntry(
          title: 'Request Submitted',
          status: 'Completed',
          date: submitted,
          timestamp: _formatTimestamp(submitted),
          description: 'Your reservation request was submitted successfully.',
        ),
      );

      if (facultyApproval != null) {
        final facultyName =
            await _getUserDisplayName(
              facultyApproval['approver_user_id'] as int,
            ) ??
            'Selected faculty';
        final approvalStatus =
            (facultyApproval['status'] as String? ?? 'pending')
                .trim()
                .toLowerCase();
        final status = switch (approvalStatus) {
          'approved' || 'accepted' || 'completed' => 'Approved',
          'rejected' || 'denied' => 'Rejected',
          'cancelled' || 'canceled' => 'Cancelled',
          _ => 'Pending',
        };
        final reason =
            (facultyApproval['rejection_reason'] as String?)?.trim() ?? '';
        final approvalDate =
            DateTime.tryParse(
              facultyApproval['updated_at']?.toString() ?? '',
            ) ??
            submitted;
        entries.add(
          ReservationTimelineEntry(
            title: 'Faculty Approval - $facultyName',
            status: status,
            date: approvalDate,
            timestamp: status == 'Pending'
                ? 'Pending'
                : _formatTimestamp(approvalDate),
            description: status == 'Rejected'
                ? reason.isEmpty
                      ? 'Rejected by $facultyName.'
                      : 'Rejected by $facultyName: $reason'
                : status == 'Approved'
                ? 'Approved by $facultyName.'
                : status == 'Cancelled'
                ? 'Cancelled because the request was rejected.'
                : 'Waiting for $facultyName to review your request.',
            approvedAt: status == 'Approved' ? approvalDate : null,
          ),
        );
      }

      final used = List<bool>.filled(rawApprovals.length, false);
      final itemOwnerOfficeId = await _getOfficeIdByName('Item Owner');

      // First pass: attempt to match rows to canonical slots by office_id or office_name
      final slots = <Map<String, dynamic>>[];
      for (var i = 0; i < approvalChain.officeIds.length; i++) {
        final expectedOfficeId = approvalChain.officeIds[i];
        final displayName = approvalChain.offices[i];

        int matchIndex = -1;
        for (var j = 0; j < rawApprovals.length; j++) {
          if (used[j]) continue;
          if (displayName.toLowerCase() == 'program chair' &&
              rawApprovals[j]['approval_stage'] == 'program_chair') {
            matchIndex = j;
            break;
          }
          final rowOfficeId = rawApprovals[j]['office_id'] as int?;
          if (rowOfficeId != null &&
              expectedOfficeId != null &&
              rowOfficeId == expectedOfficeId) {
            matchIndex = j;
            break;
          }
        }

        // Fallback: match by office name (normalized contains) when ID matching failed
        if (matchIndex == -1) {
          final expectedNorm = displayName.toLowerCase().replaceAll(
            RegExp(r"\s+"),
            '',
          );
          for (var j = 0; j < rawApprovals.length; j++) {
            if (used[j]) continue;
            final rowName = (rawApprovals[j]['office_name'] as String?)
                ?.toLowerCase();
            if (rowName == null) continue;
            final rowNorm = rowName.replaceAll(RegExp(r"\s+"), '');
            if (rowNorm.contains(expectedNorm) ||
                expectedNorm.contains(rowNorm)) {
              matchIndex = j;
              break;
            }
          }
        }

        // Reserve if matched now
        if (matchIndex != -1) used[matchIndex] = true;

        slots.add({
          'index': i,
          'displayName': displayName,
          'expectedOfficeId': expectedOfficeId,
          'matchIndex': matchIndex,
        });
      }

      if (requesterIsDean) {
        slots.removeWhere((slot) => slot['displayName'] == 'Program Chair');
      }
      final chairSlotIndex = slots.indexWhere(
        (slot) => slot['displayName'] == 'Program Chair',
      );
      final programChairApprovalIndex = rawApprovals.indexWhere(
        (row) => row['approval_stage'] == 'program_chair',
      );
      final deanApprovalIndex = rawApprovals.indexWhere(
        (row) => row['approval_stage'] == 'dean',
      );
      if (chairSlotIndex >= 0 &&
          programChairApprovalIndex >= 0 &&
          deanApprovalIndex >= 0) {
        final parallelApprovals = [
          programChairApprovalIndex,
          deanApprovalIndex,
        ];
        final preferredStatuses = [
          'approved',
          'rejected',
          'condition requested',
          'condition accepted',
          'condition rejected',
          'pending',
          'waiting',
          'completed',
          'returned',
          'cancelled',
          'canceled',
        ];
        var selectedApprovalIndex = programChairApprovalIndex;
        for (final preferredStatus in preferredStatuses) {
          var found = false;
          for (final approvalIndex in parallelApprovals) {
            final rowStatus = (rawApprovals[approvalIndex]['status'] as String?)
                ?.trim()
                .toLowerCase();
            if (rowStatus == preferredStatus) {
              selectedApprovalIndex = approvalIndex;
              found = true;
              break;
            }
          }
          if (found) {
            break;
          }
        }

        used[programChairApprovalIndex] = true;
        used[deanApprovalIndex] = true;
        slots[chairSlotIndex]
          ..['displayName'] = 'Program Chair / Dean'
          ..['matchIndex'] = selectedApprovalIndex;
      }

      // Second pass: assign any remaining rows to unmatched slots using best-effort (prefer approved rows)
      final remainingRowIndexes = <int>[];
      for (var j = 0; j < rawApprovals.length; j++) {
        if (!used[j]) remainingRowIndexes.add(j);
      }

      final unmatchedSlots = slots.where((s) => s['matchIndex'] == -1).toList();
      for (final slot in unmatchedSlots) {
        if (remainingRowIndexes.isEmpty) break;

        int pick = -1;
        // prefer an approved/completed/accepted row
        for (var k = 0; k < remainingRowIndexes.length; k++) {
          final ri = remainingRowIndexes[k];
          final rs =
              (rawApprovals[ri]['status'] as String?)?.toLowerCase() ?? '';
          if (rs.contains('approved') ||
              rs.contains('completed') ||
              rs.contains('accepted')) {
            pick = ri;
            remainingRowIndexes.removeAt(k);
            break;
          }
        }

        // otherwise pick the earliest by created_at
        if (pick == -1) {
          int earliestIdx = -1;
          int? earliestTs;
          for (var k = 0; k < remainingRowIndexes.length; k++) {
            final ri = remainingRowIndexes[k];
            final created = rawApprovals[ri]['created_at'] as String?;
            int ts;
            try {
              ts = DateTime.parse(
                created ?? DateTime.now().toIso8601String(),
              ).millisecondsSinceEpoch;
            } catch (_) {
              ts = DateTime.now().millisecondsSinceEpoch;
            }
            if (earliestTs == null || ts < earliestTs) {
              earliestTs = ts;
              earliestIdx = k;
            }
          }
          if (earliestIdx != -1) {
            pick = remainingRowIndexes.removeAt(earliestIdx);
          }
        }

        if (pick != -1) {
          // Mark used and set matchIndex on slot
          used[pick] = true;
          slot['matchIndex'] = pick;
          try {
            print(
              'DEBUG: reservation $reservationId second-pass assigned row $pick to slot ${slot['index']} (${slot['displayName']})',
            );
          } catch (_) {}
        }
      }

      // Now build entries preserving slot order
      for (final slot in slots) {
        var displayName = slot['displayName'] as String;
        final isParallelProgramChairDean =
            displayName == 'Program Chair / Dean';
        final matchIndex = slot['matchIndex'] as int;

        String status = 'Pending';
        String timestamp = 'Pending';
        String description = 'Waiting for approval from $displayName.';

        if (matchIndex != -1) {
          final row = rawApprovals[matchIndex];
          if (!isParallelProgramChairDean &&
              displayName == 'Program Chair' &&
              row['approval_stage'] == 'dean') {
            displayName = row['office_name'] as String? ?? 'Dean';
          } else if (!isParallelProgramChairDean &&
              displayName == 'Program Chair' &&
              row['approval_stage'] != 'program_chair' &&
              (row['office_name'] as String?)?.toLowerCase() == 'dean') {
            displayName = 'Dean';
          }
          displayName = approvalOfficeLabel(displayName);
          final rowStatus =
              (row['status'] as String?)?.trim().toLowerCase() ?? 'pending';
          if (rowStatus.contains('returned')) {
            status = 'Returned';
          } else if (rowStatus == 'approved' || rowStatus == 'accepted') {
            status = 'Approved';
          } else if (rowStatus == 'completed' || rowStatus == 'complete') {
            status = 'Completed';
          } else if (rowStatus == 'rejected' || rowStatus == 'denied') {
            status = 'Rejected';
          } else if (rowStatus == 'condition requested') {
            status = 'Condition Requested';
          } else if (rowStatus == 'condition accepted') {
            status = 'Condition Accepted';
          } else if (rowStatus == 'condition rejected') {
            status = 'Condition Rejected';
          } else if (rowStatus == 'cancelled' || rowStatus == 'canceled') {
            status = 'Cancelled';
          } else if (rowStatus == 'waiting') {
            status = 'Waiting';
          } else {
            status = 'Pending';
          }
          if (status == 'Pending' ||
              status == 'Waiting' ||
              status.startsWith('Condition ')) {
            timestamp = 'Pending';
          } else {
            timestamp = _formatStoredApprovalTime(row, date);
          }
          final approvalRole = row['approval_stage'] == 'dean'
              ? 'Dean'
              : 'Program Chair';
          if (isParallelProgramChairDean &&
              (status == 'Pending' || status == 'Waiting')) {
            description =
                'Waiting for either the Program Chair or Dean to review this request.';
          } else {
            description = status == 'Approved'
                ? 'Your reservation has been approved by the $approvalRole.'
                : status == 'Completed'
                ? 'This reservation has been completed.'
                : status == 'Returned'
                ? 'This reservation has been returned and the item units are available again.'
                : status == 'Rejected'
                ? 'Your reservation was rejected by the $approvalRole.'
                : status == 'Condition Requested'
                ? '$approvalRole asks you to reconsider: ${(row['reconsideration_message'] as String?)?.trim() ?? ''}'
                : status == 'Condition Accepted'
                ? 'You accepted the $approvalRole condition. Waiting for the final decision.'
                : status == 'Condition Rejected'
                ? 'You declined the $approvalRole condition. Waiting for the final decision.'
                : status == 'Cancelled'
                ? 'This reservation was cancelled.'
                : status == 'Waiting'
                ? '$displayName will review this request after the previous approval.'
                : 'Waiting for approval from $displayName.';
          }
        } else {
          displayName = approvalOfficeLabel(displayName);
        }

        entries.add(
          ReservationTimelineEntry(
            title: displayName,
            status: status,
            date: date,
            timestamp: timestamp,
            description: description,
          ),
        );
      }

      return entries;
    } catch (e) {
      print('Error building approval timeline: $e');
      return [
        ReservationTimelineEntry(
          title: 'Request Submitted',
          status: 'Completed',
          date: submittedAt ?? date,
          timestamp: _formatTimestamp(submittedAt ?? date),
          description: 'Your reservation request was submitted successfully.',
        ),
        ReservationTimelineEntry(
          title: 'Request Pending',
          status: 'Pending',
          date: date,
          timestamp: 'Pending',
          description: 'Waiting for your reservation to be reviewed.',
        ),
      ];
    }
  }

  /// Debug helper: print raw and sorted approval entries for a reservation.
  Future<void> printDebugApprovalOrder(int reservationId) async {
    try {
      final itemOwnerNames = await _getReservationItemOwnerNames(reservationId);
      final approvalsResponse = await _client
          .from('reservation_approvals')
          .select('office_id, status, created_at, updated_at')
          .eq('reservation_id', reservationId)
          .order('created_at', ascending: true);

      if (approvalsResponse == null) {
        print('DEBUG: reservation $reservationId no approvals found');
        return;
      }

      final approvalEntries = <Map<String, dynamic>>[];
      for (final approval in approvalsResponse as List) {
        final officeId = approval['office_id'] as int?;
        String officeName = officeId == null
            ? 'Approval Step'
            : (await _getOfficeById(officeId))?['department_name'] as String? ??
                  'Approval Step';
        if (officeName.toLowerCase() == 'item owner' &&
            itemOwnerNames.isNotEmpty) {
          officeName = itemOwnerNames.join(', ');
        }
        approvalEntries.add({
          'office_name': officeName,
          'status': approval['status'],
          'created_at': approval['created_at'],
          'office_id': officeId,
        });
      }

      print(
        'DEBUG: reservation $reservationId raw approvals: ${approvalEntries.map((e) => e['office_name']).toList()}',
      );

      final ordered = sortApprovalEntriesForTimeline(
        approvalEntries,
        itemOwnerOfficeId: await _getOfficeIdByName('Item Owner'),
        generalEducationOfficeId: await _getOfficeIdByName('General Education'),
      );

      print(
        'DEBUG: reservation $reservationId ordered approvals: ${ordered.map((e) => e['office_name']).toList()}',
      );
    } catch (e) {
      print('DEBUG: error printing approval order for $reservationId: $e');
    }
  }

  Future<String?> _getReservationRoomType(int reservationId) async {
    try {
      final detailResponse = await _client
          .from('reservation_details')
          .select('reservation_rooms_id')
          .eq('reservation_id', reservationId)
          .limit(1)
          .maybeSingle();

      final roomReservationId = detailResponse?['reservation_rooms_id'] as int?;
      if (roomReservationId == null) return null;

      final roomReservation = await _client
          .from('reservation_rooms')
          .select('room_id')
          .eq('reservation_rooms_id', roomReservationId)
          .limit(1)
          .maybeSingle();
      final roomId = roomReservation?['room_id'] as int?;
      if (roomId == null) return null;

      final room = await _client
          .from('rooms')
          .select('room_type')
          .eq('room_id', roomId)
          .limit(1)
          .maybeSingle();

      return room?['room_type'] as String?;
    } catch (e) {
      print('Error fetching reservation room type: $e');
      return null;
    }
  }

  Future<List<int>> _getReservationItemIds(int reservationId) async {
    final ids = <int>[];
    try {
      final details = await _client
          .from('reservation_details')
          .select('reservation_items_id')
          .eq('reservation_id', reservationId);
      if (details == null) return ids;
      final itemIds = await Future.wait(
        (details as List).map((det) async {
          final reservationItemsId = det['reservation_items_id'] as int?;
          if (reservationItemsId == null) return null;

          final itemLink = await _client
              .from('reservation_items')
              .select('item_id')
              .eq('reservation_items_id', reservationItemsId)
              .maybeSingle();
          final itemId = itemLink?['item_id'] as int?;
          return itemId;
        }),
      );
      ids.addAll(itemIds.whereType<int>());
    } catch (e) {
      print('Error fetching reservation item ids: $e');
    }
    return ids;
  }

  // MARK: - Reservation Creation

  Future<int> createInstitutionalEventReservation({
    required String activityName,
    required int userId,
    required List<InstitutionalEventVenueSchedule> venues,
    required List<InstitutionalEventEquipmentRequest> equipment,
    required bool hasOutsideParticipants,
    required String proofOfConsentUrl,
  }) async {
    if (venues.isEmpty) {
      throw ArgumentError('An Institutional Event needs at least one venue.');
    }
    final response = await _client.rpc(
      'create_institutional_event_reservation',
      params: {
        'p_user_id': userId,
        'p_activity_name': activityName,
        'p_outside_participants': hasOutsideParticipants,
        'p_proof_of_consent_url': proofOfConsentUrl,
        'p_venues': venues
            .map(
              (venue) => {
                'room_id': venue.roomId,
                'start_time': venue.startTime.toIso8601String(),
                'end_time': venue.endTime.toIso8601String(),
              },
            )
            .toList(),
        'p_equipment': equipment
            .map(
              (request) => {
                'item_id': request.itemId,
                'quantity': request.quantity,
                'venue_index': request.venueIndex,
              },
            )
            .toList(),
      },
    );
    if (response is int) return response;
    if (response is num) return response.toInt();
    throw StateError(
      'The Institutional Event reservation was not confirmed by the server.',
    );
  }

  /// Create a new reservation with approval chain
  Future<int?> createReservation({
    required String activityName,
    required int userId,
    required int roomId,
    required DateTime dateOfActivity,
    required DateTime startTime,
    required DateTime endTime,
    required List<int>? chairsQuantity,
    required List<int>? itemIds,
    Map<int, int>? itemQuantities,
    required bool hasOutsideParticipants,
    required List<int> approvalChain,
    String? proofOfConsentUrl,
    int? facultyApproverId,
  }) async {
    try {
      final normalizedItemQuantities = <int, int>{};
      if (itemQuantities != null && itemQuantities.isNotEmpty) {
        for (final entry in itemQuantities.entries) {
          final qty = entry.value;
          if (qty > 0) {
            normalizedItemQuantities[entry.key] = qty;
          }
        }
      } else if (itemIds != null && itemIds.isNotEmpty) {
        for (final itemId in itemIds) {
          normalizedItemQuantities[itemId] = 1;
        }
      }

      final resolvedItemIds = normalizedItemQuantities.keys.toList();

      if (normalizedItemQuantities.isNotEmpty) {
        for (final itemId in normalizedItemQuantities.keys) {
          final quantity = normalizedItemQuantities[itemId]!;
          if (quantity <= 0) {
            throw Exception(
              'Invalid quantity requested for item $itemId: $quantity',
            );
          }

          final availableUnits = await _getAvailableItemUnits(
            itemId,
            quantity,
            requestStart: startTime,
            requestEnd: endTime,
          );
          if (availableUnits.length < quantity) {
            throw Exception(
              'Not enough available units for item $itemId: requested $quantity, available ${availableUnits.length}',
            );
          }
        }
      }

      final routing = await _resolveRequesterApprovalRouting(
        userId,
        facultyApproverId: facultyApproverId,
      );
      await _validateProgramChairStep(approvalChain);

      // Prevent overlapping reservations for the same room/time
      final conflict = await _roomTimeIsTaken(
        roomId: roomId,
        reservationDate: dateOfActivity,
        startTime: startTime,
        endTime: endTime,
      );
      if (conflict) {
        print(
          'Cannot create reservation: time conflict for room $roomId on $dateOfActivity',
        );
        return null;
      }

      final reservationData = {
        'user_id': userId,
        'activity_name': activityName,
        'overall_status': 'Pending Approval',
        'Date_of_Activity': dateOfActivity.toIso8601String(),
        'Start_of_activity': startTime.toIso8601String(),
        'End_of_Activity': endTime.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'outside_participants': hasOutsideParticipants,
      };

      // Add proof of consent URL if provided (for students)
      if (proofOfConsentUrl != null) {
        reservationData['proof_of_consent_url'] = proofOfConsentUrl;
      }

      final authUser = _client.auth.currentUser;
      print(
        'Reservation identity check: profile=$userId, '
        'authEmail=${authUser?.email}, authUserId=${authUser?.id}',
      );

      final reservationId =
          (await _client.rpc(
                'create_reservation_header',
                params: {
                  'p_user_id': userId,
                  'p_activity_name': activityName,
                  'p_date_of_activity': dateOfActivity.toIso8601String(),
                  'p_start_of_activity': startTime.toIso8601String(),
                  'p_end_of_activity': endTime.toIso8601String(),
                  'p_outside_participants': hasOutsideParticipants,
                  'p_proof_of_consent_url': proofOfConsentUrl,
                },
              ))
              as int;

      final roomReservationResponse =
          await _client.from('reservation_rooms').insert({
            'reservation_id': reservationId,
            'room_id': roomId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).select();

      final reservationRoomsId =
          roomReservationResponse[0]['reservation_rooms_id'] as int;

      await _client.from('reservation_details').insert({
        'reservation_id': reservationId,
        'reservation_rooms_id': reservationRoomsId,
        'quantity': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (chairsQuantity != null &&
          chairsQuantity.isNotEmpty &&
          chairsQuantity[0] > 0) {
        await _client.from('reservation_details').insert({
          'reservation_id': reservationId,
          'quantity': chairsQuantity[0],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (resolvedItemIds.isNotEmpty) {
        for (final itemId in resolvedItemIds) {
          final quantity = normalizedItemQuantities[itemId]!;
          final itemResponse = await _client.from('reservation_items').insert({
            'reservation_id': reservationId,
            'item_id': itemId,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          }).select();

          final reservationItemsId =
              itemResponse[0]['reservation_items_id'] as int;

          await _client.from('reservation_details').insert({
            'reservation_id': reservationId,
            'reservation_items_id': reservationItemsId,
            'quantity': quantity,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });

          await _reserveItemUnitsForReservation(
            reservationItemsId: reservationItemsId,
            itemId: itemId,
            quantity: quantity,
            requestStart: startTime,
            requestEnd: endTime,
          );
        }
      }

      await _insertRoutedApprovalRows(
        reservationId: reservationId,
        facultyApproverId: facultyApproverId,
        officeIds: approvalChain,
        routing: routing,
      );

      return reservationId;
    } catch (error, stackTrace) {
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Get dates with conflicts for a specific room
  Future<Set<DateTime>> getConflictedDatesForRoom(int roomId) async {
    try {
      final response = await _client
          .from('reservations')
          .select('Date_of_Activity')
          .eq('room_id', roomId)
          .neq('overall_status', 'Cancelled');

      final conflictedDates = <DateTime>{};

      for (var res in response as List) {
        final dateStr = res['Date_of_Activity'] as String;
        final date = DateTime.parse(dateStr);
        conflictedDates.add(DateTime(date.year, date.month, date.day));
      }

      return conflictedDates;
    } catch (e) {
      print('Error fetching conflicted dates: $e');
      return {};
    }
  }

  // MARK: - File Operations

  /// Upload proof of consent file to Supabase Storage
  Future<void> uploadProofOfConsent(File file, String filePath) async {
    try {
      await _client.storage
          .from('proof_of_consent')
          .upload(
            filePath,
            file,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );
      print('Successfully uploaded proof of consent to: $filePath');
    } catch (e) {
      print('Error uploading proof of consent: $e');
      try {
        final serviceRoleKey = SupabaseService.serviceRoleKey;
        if (serviceRoleKey.isEmpty) {
          rethrow;
        }

        final storageClient = SupabaseClient(
          SupabaseService.supabaseUrl,
          serviceRoleKey,
        );

        await storageClient.storage
            .from('proof_of_consent')
            .upload(
              filePath,
              file,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: false,
              ),
            );
        print(
          'Successfully uploaded proof of consent via service-role fallback: $filePath',
        );
      } catch (fallbackError) {
        print('Service-role upload fallback failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Get public URL for uploaded proof of consent file
  String getProofOfConsentUrl(String filePath) {
    try {
      final url = _client.storage
          .from('proof_of_consent')
          .getPublicUrl(filePath);
      return url;
    } catch (e) {
      print('Error getting proof of consent URL: $e');
      rethrow;
    }
  }

  // MARK: - Item Reservation

  /// Create a new item reservation
  Future<int?> createItemReservation({
    required String activityName,
    required int userId,
    required DateTime dateOfActivity,
    required DateTime startTime,
    required DateTime endTime,
    required Map<int, int> itemQuantities, // item_id -> quantity
    required bool hasOutsideParticipants,
    String? proofOfConsentUrl,
    int? facultyApproverId,
    DateTime? requestStart,
    DateTime? requestEnd,
  }) async {
    try {
      final reservationData = {
        'user_id': userId,
        'activity_name': activityName,
        'overall_status': 'Pending Approval',
        'Date_of_Activity': dateOfActivity.toIso8601String(),
        'Start_of_activity': startTime.toIso8601String(),
        'End_of_Activity': endTime.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'outside_participants': hasOutsideParticipants,
      };

      if (proofOfConsentUrl != null) {
        reservationData['proof_of_consent_url'] = proofOfConsentUrl;
      }

      // Validate requested item availability before persisting the reservation.
      for (final itemId in itemQuantities.keys) {
        final quantity = itemQuantities[itemId]!;
        if (quantity <= 0) {
          throw Exception(
            'Invalid quantity requested for item $itemId: $quantity',
          );
        }

        final availableUnits = await _getAvailableItemUnits(
          itemId,
          quantity,
          requestStart: requestStart,
          requestEnd: requestEnd,
        );
        if (availableUnits.length < quantity) {
          throw Exception(
            'Not enough available units for item $itemId: requested $quantity, available ${availableUnits.length}',
          );
        }
      }

      final routing = await _resolveRequesterApprovalRouting(
        userId,
        facultyApproverId: facultyApproverId,
      );
      final approvalChain = await calculateApprovalChain(
        roomType: '',
        itemIds: itemQuantities.keys.toList(),
      );
      await _validateProgramChairStep(approvalChain.officeIds);

      final reservationId =
          (await _client.rpc(
                'create_reservation_header',
                params: {
                  'p_user_id': userId,
                  'p_activity_name': activityName,
                  'p_date_of_activity': dateOfActivity.toIso8601String(),
                  'p_start_of_activity': startTime.toIso8601String(),
                  'p_end_of_activity': endTime.toIso8601String(),
                  'p_outside_participants': hasOutsideParticipants,
                  'p_proof_of_consent_url': proofOfConsentUrl,
                },
              ))
              as int;

      // Add each item to reservation_details
      for (final itemId in itemQuantities.keys) {
        final quantity = itemQuantities[itemId]!;

        // Create a reservation_items entry and link via reservation_items_id
        final itemResponse = await _client.from('reservation_items').insert({
          'reservation_id': reservationId,
          'item_id': itemId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }).select();

        final reservationItemsId =
            itemResponse[0]['reservation_items_id'] as int;

        await _client.from('reservation_details').insert({
          'reservation_id': reservationId,
          'reservation_items_id': reservationItemsId,
          'quantity': quantity,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        await _reserveItemUnitsForReservation(
          reservationItemsId: reservationItemsId,
          itemId: itemId,
          quantity: quantity,
          requestStart: requestStart,
          requestEnd: requestEnd,
        );

        // Update the item's in-use quantity from the actual unit state.
        await _recalculateItemUsageFromUnits(itemId);
      }

      print('Item reservation created: $reservationId');

      await _insertRoutedApprovalRows(
        reservationId: reservationId,
        facultyApproverId: facultyApproverId,
        officeIds: approvalChain.officeIds,
        routing: routing,
      );

      // Add a local ReservationRecord for immediate UI feedback
      try {
        final timeline = <ReservationTimelineEntry>[];
        timeline.add(
          ReservationTimelineEntry(
            title: 'Request Submitted',
            status: 'Completed',
            date: DateTime.now(),
            timestamp: _formatTimestamp(DateTime.now()),
            description: 'Your reservation request was submitted successfully.',
          ),
        );

        if (facultyApproverId != null) {
          final faculty = await _client
              .from('users')
              .select('user_id, full_name')
              .eq('user_id', facultyApproverId)
              .maybeSingle();
          final facultyName =
              (faculty?['full_name'] as String?)?.trim().isNotEmpty == true
              ? (faculty!['full_name'] as String).trim()
              : 'Selected faculty';
          timeline.add(
            ReservationTimelineEntry(
              title: 'Faculty Approval - $facultyName',
              status: 'Pending',
              date: dateOfActivity,
              timestamp: 'Pending',
              description: 'Waiting for $facultyName to review your request.',
            ),
          );
        }
        for (var index = 0; index < approvalChain.offices.length; index++) {
          final office = approvalChain.offices[index];
          final routedName = routing.isProgramChair && office == 'Program Chair'
              ? 'Dean'
              : office;
          final label = approvalOfficeLabel(routedName);
          final status = facultyApproverId != null || index > 0
              ? 'Waiting'
              : 'Pending';
          timeline.add(
            ReservationTimelineEntry(
              title: label,
              status: status,
              date: dateOfActivity,
              timestamp: status,
              description: status == 'Waiting'
                  ? '$label will review this request after the previous approval.'
                  : 'Waiting for approval from $label.',
            ),
          );
        }

        final reservedItemNames = <String>[];
        for (final itemId in itemQuantities.keys) {
          final item = await getItemDetails(itemId);
          if (item != null) reservedItemNames.add(item.itemName);
        }

        final newRecord = ReservationRecord(
          id: reservationId.toString(),
          userId: userId,
          reservationTitle: activityName.isEmpty
              ? 'Item Reservation'
              : activityName,
          roomName: 'Item Reservation',
          reservationType: 'Item Reservation',
          reservationStatus: 'Pending Approval',
          date: dateOfActivity,
          reservationTime:
              '${_formatDateTime(startTime)} - ${_formatDateTime(endTime)}',
          timeline: timeline,
          reservedItems: reservedItemNames,
        );

        ReservationActivityStore.add(newRecord);
      } catch (_) {
        // Non-fatal; UI will refresh from backend later
      }

      return reservationId;
    } catch (e, stack) {
      print('Error creating item reservation: $e');
      print(stack);
      rethrow;
    }
  }

  /// Cancel an existing reservation request.
  Future<bool> cancelReservation(int reservationId) async {
    try {
      final updateResult = await _client
          .from('reservations')
          .update({
            'overall_status': 'Cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('reservation_id', reservationId)
          .select();

      if (updateResult == null || (updateResult as List).isEmpty) {
        return false;
      }

      await _client
          .from('reservation_approvals')
          .update({
            'status': 'Cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('reservation_id', reservationId);

      final reservationDetails = await _client
          .from('reservation_details')
          .select('reservation_items_id, quantity')
          .eq('reservation_id', reservationId);

      if (reservationDetails != null) {
        for (final detail in reservationDetails as List) {
          final reservationItemsId = detail['reservation_items_id'] as int?;
          final quantity = detail['quantity'] as int? ?? 0;
          if (reservationItemsId == null || quantity <= 0) {
            continue;
          }

          final itemLink = await _client
              .from('reservation_items')
              .select('item_id')
              .eq('reservation_items_id', reservationItemsId)
              .maybeSingle();
          final itemId = itemLink?['item_id'] as int?;
          if (itemId == null) {
            continue;
          }

          final reservationUnits = await _client
              .from('reservation_item_units')
              .select('unit_id')
              .eq('reservation_items_id', reservationItemsId);

          if (reservationUnits != null) {
            for (final unit in reservationUnits as List) {
              final unitId = unit['unit_id'] as int?;
              if (unitId != null) {
                await _client
                    .from('item_units')
                    .update({
                      'status': 'available',
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('unit_id', unitId);
              }
            }
          }

          await _recalculateItemUsageFromUnits(itemId);
        }
      }

      final cancelledReservation = await _client
          .from('reservations')
          .select('reservation_id, overall_status')
          .eq('reservation_id', reservationId)
          .maybeSingle();
      if (cancelledReservation != null &&
          (cancelledReservation['overall_status'] as String? ?? '')
                  .toLowerCase() ==
              'cancelled') {
        final allReservationItems = await _client
            .from('reservation_details')
            .select('reservation_items_id')
            .eq('reservation_id', reservationId);

        if (allReservationItems != null) {
          for (final detail in allReservationItems as List) {
            final reservationItemsId = detail['reservation_items_id'] as int?;
            if (reservationItemsId == null) continue;

            final itemLink = await _client
                .from('reservation_items')
                .select('item_id')
                .eq('reservation_items_id', reservationItemsId)
                .maybeSingle();
            final itemId = itemLink?['item_id'] as int?;
            if (itemId == null) continue;

            final linkedUnits = await _client
                .from('reservation_item_units')
                .select('unit_id')
                .eq('reservation_items_id', reservationItemsId);

            if (linkedUnits != null) {
              for (final linkedUnit in linkedUnits as List) {
                final unitId = linkedUnit['unit_id'] as int?;
                if (unitId == null) continue;
                await _client
                    .from('item_units')
                    .update({
                      'status': 'available',
                      'updated_at': DateTime.now().toIso8601String(),
                    })
                    .eq('unit_id', unitId);
              }
            }

            await _recalculateItemUsageFromUnits(itemId);
          }
        }
      }

      return true;
    } catch (e) {
      print('Error cancelling reservation: $e');
      return false;
    }
  }
}
