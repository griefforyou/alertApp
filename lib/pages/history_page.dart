import "package:flutter/material.dart";
import "../models/history_record.dart";
import "../services/storage_service.dart";

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final StorageService _storage = StorageService();
  List<HistoryRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final records = await _storage.loadHistory();
    if (!mounted) return;
    setState(() {
      _records = records..sort((a, b) => b.startTime.compareTo(a.startTime));
      _loading = false;
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("清空历史记录"),
        content: const Text("确定要清空所有历史记录吗？此操作不可撤销。"),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("取消")),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text("清空")),
        ],
      ),
    );
    if (ok != true) return;
    await _storage.clearHistory();
    await _load();
  }

  /// 按日期分组（忽略时分秒），保持组内已按时间倒序。
  Map<DateTime, List<HistoryRecord>> _groupByDay() {
    final map = <DateTime, List<HistoryRecord>>{};
    for (final r in _records) {
      final day = DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
      map.putIfAbsent(day, () => []).add(r);
    }
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return {for (final d in days) d: map[d]!};
  }

  String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) return "$h时$m分";
    if (m > 0) return "$m分钟";
    return "$seconds秒";
  }

  String _fmtTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return "${two(t.hour)}:${two(t.minute)}";
  }

  String _fmtDay(DateTime d) {
    final today = DateTime.now();
    final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
    if (isToday) return "今天";
    final y = today.subtract(const Duration(days: 1));
    final isYesterday = d.year == y.year && d.month == y.month && d.day == y.day;
    if (isYesterday) return "昨天";
    return "${d.year}年${d.month}月${d.day}日";
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("历史记录"),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _confirmClear,
              tooltip: "清空",
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _records.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 56, color: cs.onSurface.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      Text("暂无历史记录", style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
                    ],
                  ),
                )
              : (() {
                  final grouped = _groupByDay();
                  return ListView.builder(
                    padding: const EdgeInsets.only(bottom: 24),
                    itemCount: grouped.length,
                    itemBuilder: (ctx, index) {
                      final day = grouped.keys.elementAt(index);
                      final dayRecords = grouped[day]!;
                      final dayTotal = dayRecords.fold<int>(0, (s, r) => s + r.durationSeconds);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Row(
                            children: [
                              Text(
                                _fmtDay(day),
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.primary),
                              ),
                              const Spacer(),
                              Text(
                                "合计 ${_fmtDuration(dayTotal)}",
                                style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        ),
                        ...dayRecords.map((r) => ListTile(
                              leading: CircleAvatar(
                                backgroundColor: cs.primaryContainer,
                                child: Icon(Icons.timer_outlined, color: cs.onPrimaryContainer, size: 20),
                              ),
                              title: Text(r.typeName),
                              subtitle: Text("开始 ${_fmtTime(r.startTime)}"),
                              trailing: Text(_fmtDuration(r.durationSeconds),
                                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
                            )),
                      ],
                    );
                  },
                  );
                }()),
    );
  }
}
