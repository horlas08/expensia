import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/services/database_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/shared_preferences_service.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _dailyReminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  bool _loading = true;
  List<Map<String, dynamic>> _reminders = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final prefs = await SharedPreferencesService.getInstance();
    final isEnabled = prefs.getBoolean('daily_reminder_enabled') ?? false;
    final hour = prefs.getInt('daily_reminder_hour') ?? 20;
    final minute = prefs.getInt('daily_reminder_minute') ?? 0;
    final reminders = await DatabaseService().getReminders();

    setState(() {
      _dailyReminderEnabled = isEnabled;
      _reminderTime = TimeOfDay(hour: hour, minute: minute);
      _reminders = reminders;
      _loading = false;
    });
  }

  Future<void> _reloadReminders() async {
    final reminders = await DatabaseService().getReminders();
    setState(() => _reminders = reminders);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferencesService.getInstance();
    await prefs.setBoolean('daily_reminder_enabled', _dailyReminderEnabled);
    await prefs.setInt('daily_reminder_hour', _reminderTime.hour);
    await prefs.setInt('daily_reminder_minute', _reminderTime.minute);

    if (_dailyReminderEnabled) {
      await NotificationService().scheduleDailyReminder(
        id: 9999,
        title: 'Expensia',
        body: 'Time to review your daily expenses 🚀',
        time: _reminderTime,
      );
    } else {
      await NotificationService().cancel(9999);
    }
  }

  Future<void> _toggleDailyReminder(bool value) async {
    if (value) {
      final granted = await NotificationService().requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'common.error'.tr()}: Permissions not granted'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }
    setState(() => _dailyReminderEnabled = value);
    await _saveSettings();
  }

  Future<void> _pickTime() async {
    final now = DateTime.now();
    final initialDateTime =
        DateTime(now.year, now.month, now.day, _reminderTime.hour, _reminderTime.minute);

    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SizedBox(
        height: 250,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('common.cancel'.tr())),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _saveSettings();
                  },
                  child: Text('common.save'.tr()),
                ),
              ],
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: initialDateTime,
                onDateTimeChanged: (dt) {
                  setState(() => _reminderTime = TimeOfDay(hour: dt.hour, minute: dt.minute));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddReminderDialog({Map<String, dynamic>? existing}) async {
    final cs = Theme.of(context).colorScheme;
    final titleCtrl = TextEditingController(text: existing?['title']?.toString() ?? '');
    final bodyCtrl = TextEditingController(text: existing?['body']?.toString() ?? '');
    DateTime selectedDate = existing != null && existing['scheduled_date'] != null
        ? DateTime.tryParse(existing['scheduled_date'].toString()) ?? DateTime.now().add(const Duration(hours: 1))
        : DateTime.now().add(const Duration(hours: 1));
    String selectedRepeat = existing?['repeat_type']?.toString() ?? 'once';

    final repeatOptions = ['once', 'daily', 'weekly', 'monthly'];
    final repeatLabels = {'once': 'One-time', 'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: cs.onSurface.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    existing != null ? 'Edit Reminder' : 'Add Reminder',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Title Field
                  _sheetLabel('Title'),
                  const SizedBox(height: 8),
                  _sheetTextField(titleCtrl, 'Reminder title...', cs),
                  const SizedBox(height: 16),

                  // Body Field
                  _sheetLabel('Description (optional)'),
                  const SizedBox(height: 8),
                  _sheetTextField(bodyCtrl, 'Add more details...', cs, maxLines: 3),
                  const SizedBox(height: 16),

                  // Date/Time
                  _sheetLabel('Date & Time'),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date == null) return;
                      final time = await showTimePicker(context: ctx, initialTime: TimeOfDay.fromDateTime(selectedDate));
                      if (time != null) {
                        setSheetState(() {
                          selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.event_rounded, color: cs.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('EEE, MMM d • h:mm a').format(selectedDate),
                            style: TextStyle(fontWeight: FontWeight.w600, color: cs.onSurface),
                          ),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Repeat Type
                  _sheetLabel('Repeat'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: repeatOptions.map((opt) {
                      final selected = selectedRepeat == opt;
                      return ChoiceChip(
                        label: Text(repeatLabels[opt]!),
                        selected: selected,
                        onSelected: (_) => setSheetState(() => selectedRepeat = opt),
                        selectedColor: cs.primary,
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : cs.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        backgroundColor: cs.surfaceContainerLow,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a title')),
                          );
                          return;
                        }
                        await DatabaseService().addReminder(
                          title: title,
                          body: bodyCtrl.text.trim().isEmpty ? null : bodyCtrl.text.trim(),
                          repeatType: selectedRepeat,
                          scheduledDate: selectedDate.toIso8601String(),
                        );
                        // Schedule local notification
                        final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
                        await NotificationService().scheduleReminder(
                          id: id,
                          title: title,
                          body: bodyCtrl.text.trim().isEmpty ? 'Reminder from Expensia' : bodyCtrl.text.trim(),
                          scheduledDate: selectedDate,
                          repeatType: selectedRepeat,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _reloadReminders();
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Save Reminder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetLabel(String label) => Text(
    label,
    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
  );

  Widget _sheetTextField(TextEditingController ctrl, String hint, ColorScheme cs, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: cs.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('profile.notifications'.tr()),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddReminderDialog,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Add Reminder'),
        backgroundColor: cs.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
        children: [
          // ── Daily Reminder Section ──
          _buildSectionHeader(context, 'Daily Reminder', Icons.notifications_rounded),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Daily Reminder',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Remind me to log expenses',
                          style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                    Switch.adaptive(value: _dailyReminderEnabled, onChanged: _toggleDailyReminder),
                  ],
                ),
                if (_dailyReminderEnabled) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  InkWell(
                    onTap: _pickTime,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.access_time_rounded, color: cs.primary, size: 20),
                              const SizedBox(width: 12),
                              const Text('Time', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _reminderTime.format(context),
                              style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ── Custom Reminders Section ──
          _buildSectionHeader(context, 'Custom Reminders', Icons.alarm_rounded),
          const SizedBox(height: 12),
          if (_reminders.where((r) => r['type'] == 'custom').isEmpty)
            _buildEmptyState(context)
          else
            ..._reminders
                .where((r) => r['type'] == 'custom')
                .map((r) => _buildReminderCard(context, r, cs)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: cs.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.alarm_add_rounded, size: 48, color: cs.onSurface.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            'No custom reminders yet.\nTap the button below to add one.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Map<String, dynamic> r, ColorScheme cs) {
    final title = r['title']?.toString() ?? 'Reminder';
    final body = r['body']?.toString() ?? '';
    final repeatType = r['repeat_type']?.toString() ?? 'once';
    final scheduledDate = r['scheduled_date'] != null
        ? DateTime.tryParse(r['scheduled_date'].toString())
        : null;

    final repeatLabels = {'once': 'One-time', 'daily': 'Daily', 'weekly': 'Weekly', 'monthly': 'Monthly'};
    final repeatColors = {
      'once': Colors.blue,
      'daily': Colors.green,
      'weekly': Colors.orange,
      'monthly': Colors.purple,
    };
    final repeatColor = repeatColors[repeatType] ?? cs.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: repeatColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.alarm_rounded, color: repeatColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(body, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (scheduledDate != null) ...[
                      Icon(Icons.schedule_rounded, size: 13, color: cs.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('MMM d, yyyy  •  h:mm a').format(scheduledDate),
                        style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: repeatColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        repeatLabels[repeatType] ?? repeatType,
                        style: TextStyle(color: repeatColor, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Reminder'),
                  content: Text('Delete "$title"?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await DatabaseService().deleteReminder(r['id'] as int);
                await _reloadReminders();
              }
            },
            icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.4)),
          ),
        ],
      ),
    );
  }
}
