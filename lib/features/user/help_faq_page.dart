import 'package:flutter/material.dart';
import 'package:new_nutilize_mobile/features/user/report_issue_page.dart';
import 'package:new_nutilize_mobile/widgets/app_bottom_nav.dart';
import 'package:new_nutilize_mobile/widgets/app_header.dart';
import 'package:new_nutilize_mobile/widgets/app_shell_scope.dart';

class HelpFaqPage extends StatefulWidget {
  const HelpFaqPage({super.key});

  @override
  State<HelpFaqPage> createState() => _HelpFaqPageState();
}

class _HelpFaqPageState extends State<HelpFaqPage> {
  final List<_FaqItem> _faqs = [
    _FaqItem(
      question: 'How do I reserve a room?',
      answer:
          'Go to the reservation page, choose a room type, pick your preferred date and time, and submit your request for approval.',
    ),
    _FaqItem(
      question: 'How long does approval take?',
      answer:
          'Most requests are reviewed within 1 to 2 business days, depending on the department and availability.',
    ),
    _FaqItem(
      question: 'Can I cancel my reservation?',
      answer:
          'Yes. If your reservation has not been finalized, you can cancel it from the reservation details screen or contact support.',
    ),
    _FaqItem(
      question: 'Why was my reservation rejected?',
      answer:
          'Reservations may be rejected if the room is unavailable, the requested time conflicts with another booking, or the form is incomplete.',
    ),
    _FaqItem(
      question: 'Who do I contact for assistance?',
      answer:
          'You can reach the support team through the Contact Support button below or submit a report directly from the app.',
    ),
  ];

  final Set<int> _expandedItems = <int>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FB),
      body: SafeArea(
        child: Column(
          children: [
            const AppHeader(title: 'NUtilize'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                children: [
                  const Text(
                    'Help & FAQ',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Find quick answers to common questions about reservations and support.',
                    style: TextStyle(
                      color: Color(0xFF6A6F86),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(_faqs.length, (index) {
                    final faq = _faqs[index];
                    final isExpanded = _expandedItems.contains(index);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: Text(
                              faq.question,
                              style: const TextStyle(
                                color: Color(0xFF111111),
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            trailing: Icon(
                              isExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: const Color(0xFF35489A),
                            ),
                            initiallyExpanded: isExpanded,
                            onExpansionChanged: (expanded) {
                              setState(() {
                                if (expanded) {
                                  _expandedItems.add(index);
                                } else {
                                  _expandedItems.remove(index);
                                }
                              });
                            },
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Text(
                                  faq.answer,
                                  style: const TextStyle(
                                    color: Color(0xFF6A6F86),
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReportIssuePage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('Contact Support'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF35489A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AppBottomNav(
              selectedIndex: AppShellScope.maybeOf(context)?.currentIndex ?? 3,
              onTap: AppShellScope.maybeOf(context)?.onTabSelected ?? (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;
}
