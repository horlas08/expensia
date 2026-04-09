import 'package:flutter/material.dart';
import 'package:animated_theme_switcher/animated_theme_switcher.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:animate_do/animate_do.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ── Profile Header ─────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: cs.primary,
            foregroundColor: Colors.white,
            title: const Text('Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [cs.primary, Colors.deepPurple],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      FadeInDown(
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: Colors.white.withValues(alpha: 0.25),
                          child: const Icon(Icons.person, size: 38, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 10),
                      FadeInUp(
                        child: const Text(
                          'John Doe',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FadeInUp(
                        delay: const Duration(milliseconds: 100),
                        child: Text(
                          'john.doe@example.com',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── General ─────────────────────────────────────────────
                  _SectionLabel(label: 'General', delay: 50),
                  FadeInUp(
                    delay: const Duration(milliseconds: 100),
                    child: _SettingsGroup(items: [
                      _SettingTile(icon: Icons.person_outline, label: 'Persons', onTap: () {}),
                      _SettingTile(icon: Icons.language, label: 'Change Language', onTap: () {}),
                      _SettingTile(icon: Icons.category_outlined, label: 'Categories', onTap: () {}),
                      _SettingTile(icon: Icons.attach_money, label: 'Default Currency', onTap: () {}),
                    ]),
                  ),

                  // ── App Preferences ─────────────────────────────────────
                  _SectionLabel(label: 'App Preferences', delay: 150),
                  FadeInUp(
                    delay: const Duration(milliseconds: 200),
                    child: _SettingsGroup(items: [
                      // Theme switcher item (custom, no extra wrapper)
                      ThemeSwitcher(
                        builder: (context) {
                          final brightness =
                              ThemeModelInheritedNotifier.of(context).theme.brightness;
                          return _SettingTile(
                            icon: brightness == Brightness.light
                                ? Icons.dark_mode_outlined
                                : Icons.light_mode_outlined,
                            label: 'Theme',
                            onTap: () {},
                            trailing: Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: brightness == Brightness.dark,
                                onChanged: (_) {
                                  ThemeSwitcher.of(context).changeTheme(
                                    theme: brightness == Brightness.light
                                        ? AppTheme.darkTheme
                                        : AppTheme.lightTheme,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      _SettingTile(icon: Icons.notifications_outlined, label: 'Notifications', onTap: () {}),
                    ]),
                  ),

                  // ── Data & Security ─────────────────────────────────────
                  _SectionLabel(label: 'Data & Security', delay: 250),
                  FadeInUp(
                    delay: const Duration(milliseconds: 300),
                    child: _SettingsGroup(items: [
                      _SettingTile(icon: Icons.backup_outlined, label: 'Backup', onTap: () {}),
                      _SettingTile(icon: Icons.restore, label: 'Restore', onTap: () {}),
                      _SettingTile(icon: Icons.lock_outline, label: 'App Lock', onTap: () {}),
                    ]),
                  ),

                  // ── Premium ─────────────────────────────────────────────
                  _SectionLabel(label: 'Premium', delay: 350),
                  FadeInUp(
                    delay: const Duration(milliseconds: 400),
                    child: GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF8C00), Color(0xFFFFD700)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withValues(alpha: 0.3),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Upgrade to Premium',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('Unlock all features', style: TextStyle(color: Colors.white70, fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── About ───────────────────────────────────────────────
                  _SectionLabel(label: 'About', delay: 450),
                  FadeInUp(
                    delay: const Duration(milliseconds: 500),
                    child: _SettingsGroup(items: [
                      _SettingTile(icon: Icons.info_outline, label: 'App Version', onTap: () {}, trailingText: '1.0.0'),
                      _SettingTile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () {}),
                      _SettingTile(icon: Icons.description_outlined, label: 'Terms & Conditions', onTap: () {}),
                      _SettingTile(icon: Icons.contact_support_outlined, label: 'Contact Us', onTap: () {}),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.delay = 0});
  final String label;
  final int delay;

  @override
  Widget build(BuildContext context) {
    return FadeInLeft(
      delay: Duration(milliseconds: delay),
      child: Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// A grouped list of settings items — no outline border, soft background only
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.items});
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: List.generate(items.length, (i) {
          return Column(
            children: [
              items[i],
              if (i < items.length - 1)
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailingText,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailingText;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = cs.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: effectiveColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: effectiveColor, fontSize: 15),
              ),
            ),
            trailing ??
                (trailingText != null
                    ? Text(trailingText!, style: const TextStyle(color: Colors.grey, fontSize: 13))
                    : Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant.withValues(alpha: 0.4), size: 20)),
          ],
        ),
      ),
    );
  }
}
