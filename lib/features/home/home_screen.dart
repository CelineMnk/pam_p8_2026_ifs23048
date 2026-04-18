// lib/features/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/todo_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadStats());
  }

  Future<void> _loadStats() async {
    final token = context.read<AuthProvider>().authToken;
    if (token == null) return;
    await context.read<TodoProvider>().loadStats(authToken: token);
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: _loadStats,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────
            SliverAppBar(
              expandedHeight: 160,
              floating: false,
              pinned: true,
              backgroundColor: colorScheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding:
                const EdgeInsets.only(left: 20, bottom: 16),
                title: Consumer<AuthProvider>(
                  builder: (_, auth, __) => Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${auth.user?.name.split(' ').first ?? 'Pengguna'} 👋',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Semangat selesaikan tugasmu!',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.primaryContainer,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
            ),

            // ── Konten ───────────────────────────
            SliverToBoxAdapter(
              child: Consumer<TodoProvider>(
                builder: (_, provider, __) {
                  if (provider.statsLoading) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  final total   = provider.totalCount;
                  final done    = provider.doneCount;
                  final undone  = provider.undoneCount;
                  final percent = provider.donePercent;

                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Progress card
                        _ProgressCard(
                          total: total, done: done,
                          undone: undone, percent: percent,
                        ),
                        const SizedBox(height: 24),

                        // Judul ringkasan
                        Text('Ringkasan',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            )),
                        const SizedBox(height: 12),

                        // 3 stat card
                        Row(
                          children: [
                            Expanded(child: _StatCard(
                              label: 'Total',
                              value: '$total',
                              icon: Icons.list_alt_rounded,
                              color: colorScheme.primary,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(
                              label: 'Selesai',
                              value: '$done',
                              icon: Icons.check_circle_rounded,
                              color: Colors.green,
                            )),
                            const SizedBox(width: 12),
                            Expanded(child: _StatCard(
                              label: 'Belum',
                              value: '$undone',
                              icon: Icons.radio_button_unchecked_rounded,
                              color: Colors.orange,
                            )),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Motivasi
                        _MotivationCard(percent: percent),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.total, required this.done,
    required this.undone, required this.percent,
  });

  final int total, done, undone;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final pct = (percent * 100).toStringAsFixed(1);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded,
                  color: colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text('Progress Keseluruhan',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$pct%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // LinearProgressIndicator
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 14,
              backgroundColor: colorScheme.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(
                percent >= 1.0 ? Colors.green : colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$done dari $total selesai',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  )),
              Text('$undone tersisa',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  )),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });

  final String label, value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold, color: color,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _MotivationCard extends StatelessWidget {
  const _MotivationCard({required this.percent});
  final double percent;

  String get _quote {
    if (percent == 0)    return 'Mulai dari yang kecil. Setiap langkah berarti! 🚀';
    if (percent < 0.3)   return 'Kamu sudah mulai! Teruskan semangatnya! 💪';
    if (percent < 0.6)   return 'Lebih dari setengah jalan sudah terlampaui! 🌟';
    if (percent < 1.0)   return 'Hampir selesai! Sedikit lagi menuju puncak! 🏆';
    return 'Luar biasa! Semua todo sudah selesai! 🎉';
  }

  @override
  Widget build(BuildContext context) {
    final theme       = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: colorScheme.secondary.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(_quote,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500, height: 1.4,
                )),
          ),
        ],
      ),
    );
  }
}