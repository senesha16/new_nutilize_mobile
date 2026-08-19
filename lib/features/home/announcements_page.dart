import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/services/announcements_service.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  late AnnouncementsService _announcementsService;
  late Future<List<AnnouncementRecord>> _future;

  @override
  void initState() {
    super.initState();
    _announcementsService = AnnouncementsService();
    _future = _announcementsService.fetchAnnouncements();
    // Subscribe to real-time updates
    _announcementsService.subscribeToAnnouncements();
    // Add listener to rebuild when announcements change
    _announcementsService.addListener(_onAnnouncementsChanged);
  }

  @override
  void dispose() {
    _announcementsService.removeListener(_onAnnouncementsChanged);
    super.dispose();
  }

  void _onAnnouncementsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF35489A),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'All Announcements',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<AnnouncementRecord>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4053A7)),
                ),
              );
            }

            final announcements = List<AnnouncementRecord>.from(
              _announcementsService.announcements,
            )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (announcements.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Announcements',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              itemCount: announcements.length,
              itemBuilder: (context, index) {
                final announcement = announcements[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _AnnouncementDetailCard(
                    announcement: announcement,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AnnouncementDetailCard extends StatelessWidget {
  const _AnnouncementDetailCard({required this.announcement});

  final AnnouncementRecord announcement;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE4E7FB),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFC9CCD6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.image_outlined,
                  color: Colors.white70,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcement.displayName,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      announcement.formattedTime,
                      style: const TextStyle(
                        color: Color(0xFF6A6F86),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: Color(0xFFE94545),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.campaign_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            announcement.title,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            announcement.body,
            style: const TextStyle(
              color: Color(0xFF60667B),
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
