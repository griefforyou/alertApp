import "package:flutter/material.dart";
import "../models/timer_profile.dart";
import "../models/round_config.dart";

class PresetEditPage extends StatefulWidget {
  final TimerProfile profile;
  const PresetEditPage({super.key, required this.profile});

  @override
  State<PresetEditPage> createState() => _PresetEditPageState();
}

class _PresetEditPageState extends State<PresetEditPage> {
  late List<RoundConfig> _rounds;
  late bool _multiCycle;
  late int _totalCycles;
  late TextEditingController _cycleController;
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _rounds = List.from(widget.profile.rounds.map((r) => r.copyWith()));
    _multiCycle = widget.profile.multiCycle;
    _totalCycles = widget.profile.totalCycles;
    _cycleController = TextEditingController(text: _totalCycles.toString());
    _nameController = TextEditingController(text: widget.profile.customName ?? "");
  }

  @override
  void dispose() {
    _cycleController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String get _typeLabel => widget.profile.displayName;

  void _addRound() {
    setState(() {
      _rounds.add(const RoundConfig(workMinutes: 2, breakMinutes: 1));
    });
  }

  void _removeRound(int index) {
    if (_rounds.length <= 1) return;
    setState(() {
      _rounds.removeAt(index);
    });
  }

  void _onSave() {
    final cycles = int.tryParse(_cycleController.text) ?? 4;
    final name = widget.profile.category == TimerCategory.custom
        ? _nameController.text.trim()
        : null;
    final profile = TimerProfile(
      id: widget.profile.id,
      category: widget.profile.category,
      customName: (name != null && name.isNotEmpty) ? name : widget.profile.customName,
      rounds: _rounds,
      multiCycle: _multiCycle,
      totalCycles: cycles.clamp(1, 999),
    );
    Navigator.of(context).pop(profile);
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = widget.profile.category == TimerCategory.custom;

    return Scaffold(
      appBar: AppBar(
        title: Text("$_typeLabel 方案"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _onSave,
              child: const Text("保存"),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isCustom)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "类型名称",
                  hintText: "例如：跑步、阅读、瑜伽",
                ),
              ),
            ),
          ..._rounds.asMap().entries.map((entry) {
            final idx = entry.key;
            final round = entry.value;
            return _RoundCard(
              roundIndex: idx,
              round: round,
              typeLabel: _typeLabel,
              canRemove: _rounds.length > 1,
              onWorkChanged: (v) {
                setState(() {
                  _rounds[idx] = round.copyWith(workMinutes: v);
                });
              },
              onBreakChanged: (v) {
                setState(() {
                  _rounds[idx] = round.copyWith(breakMinutes: v);
                });
              },
              onRemove: () => _removeRound(idx),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addRound,
            icon: const Icon(Icons.add),
            label: const Text("添加下一组"),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                CheckboxListTile(
                  title: const Text("多轮循环"),
                  subtitle: const Text("勾选后，所有轮次将循环重复"),
                  value: _multiCycle,
                  onChanged: (v) => setState(() => _multiCycle = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                if (_multiCycle)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Row(
                      children: [
                        const Text("循环轮数："),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _cycleController,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundCard extends StatelessWidget {
  final int roundIndex;
  final RoundConfig round;
  final String typeLabel;
  final bool canRemove;
  final ValueChanged<int> onWorkChanged;
  final ValueChanged<int> onBreakChanged;
  final VoidCallback onRemove;

  const _RoundCard({
    required this.roundIndex,
    required this.round,
    required this.typeLabel,
    required this.canRemove,
    required this.onWorkChanged,
    required this.onBreakChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("第 ${roundIndex + 1} 组",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const Spacer(),
                if (canRemove)
                  TextButton.icon(
                    onPressed: onRemove,
                    icon: Icon(Icons.delete_outline, size: 18, color: cs.error),
                    label: Text("删除本组", style: TextStyle(color: cs.error)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _DurationRow(
              label: typeLabel,
              value: round.workMinutes,
              onChanged: onWorkChanged,
            ),
            const SizedBox(height: 8),
            _DurationRow(
              label: "休息",
              value: round.breakMinutes,
              onChanged: onBreakChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _DurationRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text("$label：", style: const TextStyle(fontSize: 16)),
        ),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        SizedBox(
          width: 50,
          child: Text(
            "$value",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged(value + 1),
        ),
        const Text("分钟"),
      ],
    );
  }
}
