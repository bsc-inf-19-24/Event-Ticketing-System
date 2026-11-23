import 'package:flutter/material.dart';

import '../../../core/api_client.dart';
import '../../../theme/app_colors.dart';
import '../data/interest_repository.dart';
import '../models/interest.dart';

class InterestsScreen extends StatefulWidget {
  const InterestsScreen({super.key, this.repository});

  final InterestRepository? repository;

  @override
  State<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends State<InterestsScreen> {
  late final InterestRepository _repository =
      widget.repository ?? InterestRepository();
  List<Interest> _catalog = const [];
  Set<int> _selectedIds = {};
  final Set<int> _busyIds = {};
  bool _loading = true;
  bool _usingCachedData = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cachedCatalog = await _repository.fetchCatalog(cacheOnly: true);
      final cachedSelections = await _repository.fetchMyInterests(
        cacheOnly: true,
      );
      if (!mounted) return;
      setState(() {
        _catalog = cachedCatalog;
        _selectedIds = cachedSelections
            .map((value) => value.interest.id)
            .toSet();
        _usingCachedData =
            cachedCatalog.isNotEmpty || cachedSelections.isNotEmpty;
      });

      final catalog = await _repository.fetchCatalog();
      final selections = await _repository.fetchMyInterests();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _selectedIds = selections.map((value) => value.interest.id).toSet();
        _usingCachedData = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Could not load your interests.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(Interest interest) async {
    if (_busyIds.contains(interest.id)) return;
    setState(() => _busyIds.add(interest.id));
    final wasSelected = _selectedIds.contains(interest.id);
    try {
      if (wasSelected) {
        await _repository.removeInterest(interest.id);
      } else {
        await _repository.addInterest(interest.id);
      }
      final selections = await _repository.fetchMyInterests();
      if (!mounted) return;
      setState(() {
        _selectedIds = selections.map((value) => value.interest.id).toSet();
        _error = null;
        _usingCachedData = false;
      });
    } catch (error) {
      if (!mounted) return;
      try {
        final selections = await _repository.fetchMyInterests();
        setState(() {
          _selectedIds = selections.map((value) => value.interest.id).toSet();
        });
      } catch (_) {}
      setState(() {
        _error = error is ApiException
            ? error.message
            : 'Could not update this interest.';
      });
    } finally {
      if (mounted) setState(() => _busyIds.remove(interest.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Interests'),
        centerTitle: true,
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const Text(
              'Choose the topics you are interested in.',
              style: TextStyle(color: Colors.white70),
            ),
            if (_usingCachedData)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Showing cached interests.',
                  style: TextStyle(color: Colors.orangeAccent),
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            const SizedBox(height: 12),
            if (!_loading && _catalog.isEmpty && _error == null)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text(
                  'No interests are available yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ..._catalog.map((interest) {
              final selected = _selectedIds.contains(interest.id);
              final busy = _busyIds.contains(interest.id);
              return Card(
                color: selected
                    ? AppColors.accent.withValues(alpha: 0.18)
                    : const Color(0xFFEBEBE6),
                margin: const EdgeInsets.only(bottom: 10),
                child: SwitchListTile(
                  activeThumbColor: AppColors.accent,
                  title: Text(
                    interest.name,
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF333333),
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  value: selected,
                  onChanged: busy ? null : (_) => _toggle(interest),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
