import '../../domain/enums.dart';

class TeamMemberRow {
  const TeamMemberRow({
    required this.id,
    required this.userId,
    required this.role,
    required this.status,
    required this.isSelf,
    this.fullName,
    this.email,
    this.createdAt,
    this.hasPin = false,
  });

  final String id;
  final String userId;
  final StoreRole role;
  final String status;
  final bool isSelf;
  final String? fullName;
  final String? email;
  final DateTime? createdAt;
  final bool hasPin;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final mail = email?.trim();
    if (mail != null && mail.isNotEmpty) return mail;
    return 'Team member';
  }

  factory TeamMemberRow.fromJson(Map<String, dynamic> json) {
    return TeamMemberRow(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      role: StoreRole.fromValue(json['role'] as String),
      status: json['status'] as String? ?? 'active',
      isSelf: json['is_self'] == true,
      fullName: json['full_name'] as String?,
      email: json['email'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
      hasPin: json['has_pin'] == true,
    );
  }
}

class ShiftRosterMember {
  const ShiftRosterMember({
    required this.userId,
    required this.memberId,
    required this.role,
    required this.hasPin,
    required this.isSelf,
    this.fullName,
  });

  final String userId;
  final String memberId;
  final StoreRole role;
  final bool hasPin;
  final bool isSelf;
  final String? fullName;

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return isSelf ? 'You' : 'Team member';
  }

  factory ShiftRosterMember.fromJson(Map<String, dynamic> json) {
    return ShiftRosterMember(
      userId: json['user_id'] as String,
      memberId: json['member_id'] as String,
      role: StoreRole.fromValue(json['role'] as String? ?? 'staff'),
      hasPin: json['has_pin'] == true,
      isSelf: json['is_self'] == true,
      fullName: json['full_name'] as String?,
    );
  }
}

class PendingInviteRow {
  const PendingInviteRow({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.token,
    this.expiresAt,
    this.createdAt,
  });

  final String id;
  final String email;
  final StoreRole role;
  final String status;
  final String token;
  final DateTime? expiresAt;
  final DateTime? createdAt;

  factory PendingInviteRow.fromJson(Map<String, dynamic> json) {
    return PendingInviteRow(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      role: StoreRole.fromValue(json['role'] as String? ?? 'staff'),
      status: json['status'] as String? ?? 'pending',
      token: json['token'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expires_at'] as String? ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }
}

class StoreTeamSnapshot {
  const StoreTeamSnapshot({
    required this.members,
    required this.invitations,
  });

  final List<TeamMemberRow> members;
  final List<PendingInviteRow> invitations;

  factory StoreTeamSnapshot.fromJson(Map<String, dynamic> json) {
    final membersRaw = json['members'];
    final invitesRaw = json['invitations'];
    return StoreTeamSnapshot(
      members: membersRaw is List
          ? membersRaw
              .map((e) => TeamMemberRow.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
      invitations: invitesRaw is List
          ? invitesRaw
              .map((e) => PendingInviteRow.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList()
          : const [],
    );
  }
}
