import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'home_screen.dart';

class AllSitesScreen extends StatelessWidget {
  const AllSitesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final grouped = <SiteCategory, List<QuickSite>>{};
    for (final site in allSites) {
      grouped.putIfAbsent(site.category, () => []).add(site);
    }
    final categories = SiteCategory.values.where((category) => grouped.containsKey(category)).toList();

    return Scaffold(
      backgroundColor: pageBg(context),
      appBar: AppBar(toolbarHeight: 64, title: const Text('Todos os sites')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(height: 18),
        itemBuilder: (context, index) {
          final category = categories[index];
          final sites = grouped[category]!;
          return _CategorySection(category: category, sites: sites);
        },
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({required this.category, required this.sites});
  final SiteCategory category;
  final List<QuickSite> sites;

  @override
  Widget build(BuildContext context) {
    final text = mainText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
          child: Text(siteCategoryLabel(category), style: TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w800)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
          decoration: BoxDecoration(color: pillColor(context), borderRadius: BorderRadius.circular(28)),
          child: Wrap(
            spacing: 4,
            runSpacing: 16,
            alignment: WrapAlignment.start,
            children: sites.map((site) => SizedBox(width: 76, child: QuickSiteTile(site: site))).toList(),
          ),
        ),
      ],
    );
  }
}