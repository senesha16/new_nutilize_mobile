import 'package:supabase_flutter/supabase_flutter.dart';

class ProgramChairAccount {
  const ProgramChairAccount({
    required this.program,
    required this.email,
    required this.created,
    required this.note,
    this.temporaryPassword,
  });

  final String program;
  final String email;
  final bool created;
  final String note;
  final String? temporaryPassword;

  factory ProgramChairAccount.fromJson(Map<String, dynamic> json) {
    return ProgramChairAccount(
      program: json['program'] as String,
      email: json['email'] as String,
      created: json['created'] as bool,
      note: json['note'] as String,
      temporaryPassword: json['temporaryPassword'] as String?,
    );
  }
}

class ProgramChairAccountService {
  Future<ProgramChairProvisioningResult> provisionAccounts() async {
    final response = await Supabase.instance.client.functions.invoke(
      'seed_program_chairs',
      method: HttpMethod.post,
    );
    final payload = response.data;
    final status = response.status;
    if (status == null) {
      throw const FormatException(
        'The account service response did not include an HTTP status.',
      );
    }
    if (payload is! Map) {
      throw const FormatException(
        'The account service returned an unexpected response.',
      );
    }
    final rawAccounts = payload['accounts'];
    if (rawAccounts is! List) {
      if (status < 200 || status >= 300) {
        throw StateError(
          payload['message']?.toString() ??
              payload['error']?.toString() ??
              'Program Chair accounts could not be provisioned.',
        );
      }
      throw const FormatException(
        'The account service returned an unexpected response.',
      );
    }
    if (status < 200 || (status >= 300 && status != 207)) {
      throw StateError(
        payload['message']?.toString() ??
            payload['error']?.toString() ??
            'Program Chair accounts could not be provisioned.',
      );
    }
    final accounts = rawAccounts
        .map(
          (account) => ProgramChairAccount.fromJson(
            Map<String, dynamic>.from(account as Map),
          ),
        )
        .toList(growable: false);
    return ProgramChairProvisioningResult(
      accounts: accounts,
      warning: status == 207
          ? [payload['message']?.toString(), payload['warning']?.toString()]
                .whereType<String>()
                .where((message) => message.trim().isNotEmpty)
                .join('\n')
          : null,
    );
  }
}

class ProgramChairProvisioningResult {
  const ProgramChairProvisioningResult({required this.accounts, this.warning});

  final List<ProgramChairAccount> accounts;
  final String? warning;
}
