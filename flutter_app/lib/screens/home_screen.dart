import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthUser;

import '../navigation.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/greeting_header.dart';
import '../widgets/home_bottom_nav.dart';
import '../widgets/quick_actions.dart';
import '../widgets/recently_added.dart';
import '../widgets/todays_look_card.dart';

/// Home dashboard: greeting, Today's Look, search, quick actions, recently
/// added, and a floating pill bottom nav.
///
/// Every nav destination opens its own route with a back button, so the whole
/// bar behaves one way rather than mixing pushed routes with in-place swaps.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.showNav = true});

  /// False inside `NavShell`, which draws the one shared bar.
  final bool showNav;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<AuthUser?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _authSubscription = authService.onAuthStateChange.listen((_) {
      if (mounted) {
        _loadUserProfile();
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = authService.currentUser;
    if (user == null) return;

    final initialName = user.displayName.trim().isNotEmpty
        ? user.displayName.trim()
        : user.email.split('@').first;

    if (mounted) {
      setState(() {});
    }
    globalUserName.value = initialName;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('display_name')
          .eq('id', user.id)
          .maybeSingle();

      if (data != null && mounted) {
        final dbName = data['display_name'] as String?;
        final fetchedName = (dbName != null && dbName.trim().isNotEmpty)
            ? dbName.trim()
            : initialName;

        if (mounted) {
          setState(() {});
        }
        globalUserName.value = fetchedName;
      }
    } catch (e) {
      debugPrint('Error loading profile in Home: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppColors.of(context);
    return Scaffold(
      backgroundColor: palette.canvas,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const GreetingHeader(),
                    const SizedBox(height: 16),
                    Text(
                      "Today's Look",
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 24,
                        height: 30 / 24,
                        fontWeight: FontWeight.bold,
                        color: palette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const TodaysLookSection(),
                    const SizedBox(height: 20),
                    QuickActions(
                      onFavoriteTap: () => openNavDestination(
                        context,
                        1,
                        initialTab: 1,
                        initialFavoritesOnly: true,
                      ),
                      onPlannerTap: () => openNavDestination(context, 3),
                    ),
                    const SizedBox(height: 20),
                    const RecentlyAdded(),
                  ],
                ),
              ),
            ),
            if (widget.showNav)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: HomeBottomNav(
                  currentIndex: 0,
                  onTap: (index) => openNavDestination(context, index),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
