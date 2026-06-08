import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/water_vessel.dart';
import '../providers/diary_provider.dart';

class WaterVesselsScreen extends StatelessWidget {
  const WaterVesselsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final diary = context.watch<DiaryProvider>();
    final vessels = diary.vessels;

    return Scaffold(
      appBar: AppBar(title: const Text('Water Vessels')),
      body: vessels.isEmpty
          ? Center(
              child: Text(
                'No vessels yet. Tap + to add one.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          : ReorderableListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: vessels.length,
              // ignore: deprecated_member_use
              onReorder: (oldIndex, newIndex) {
                final updated = [...vessels];
                if (newIndex > oldIndex) newIndex--;
                updated.insert(newIndex, updated.removeAt(oldIndex));
                context.read<DiaryProvider>().setVessels(updated);
              },
              itemBuilder: (context, i) {
                final v = vessels[i];
                return ListTile(
                  key: Key(v.id),
                  leading: _VesselIcon(vessel: v, size: 24),
                  title: Text(v.name),
                  subtitle: Text('${v.ml} ml'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editVessel(context, diary, v),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteVessel(context, diary, v),
                      ),
                      const Icon(Icons.drag_handle),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editVessel(context, diary, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _editVessel(
      BuildContext context, DiaryProvider diary, WaterVessel? existing) async {
    final result = await showDialog<WaterVessel>(
      context: context,
      builder: (ctx) => _VesselDialog(existing: existing),
    );
    if (result == null) return;
    final vessels = [...diary.vessels];
    if (existing != null) {
      final idx = vessels.indexWhere((v) => v.id == existing.id);
      if (idx >= 0) vessels[idx] = result;
    } else {
      vessels.add(result);
    }
    diary.setVessels(vessels);
  }

  Future<void> _deleteVessel(
      BuildContext context, DiaryProvider diary, WaterVessel vessel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete vessel'),
        content: Text('Remove "${vessel.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      diary.setVessels(diary.vessels.where((v) => v.id != vessel.id).toList());
    }
  }
}

// Renders either an SvgPicture or an Icon depending on the vessel's icon type.
class _VesselIcon extends StatelessWidget {
  final WaterVessel vessel;
  final double size;
  const _VesselIcon({required this.vessel, required this.size});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.primary;
    if (vessel.isSvgIcon && vessel.svgAsset != null) {
      return SvgPicture.asset(
        vessel.svgAsset!,
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      );
    }
    return Icon(vessel.icon, size: size, color: c);
  }
}

class _VesselDialog extends StatefulWidget {
  final WaterVessel? existing;
  const _VesselDialog({this.existing});

  @override
  State<_VesselDialog> createState() => _VesselDialogState();
}

class _VesselDialogState extends State<_VesselDialog> {
  late TextEditingController _nameCtrl;
  late TextEditingController _mlCtrl;
  late VesselIconOption _selectedOption;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _mlCtrl = TextEditingController(text: widget.existing?.ml.toString() ?? '');

    final existing = widget.existing;
    if (existing != null) {
      _selectedOption = WaterVessel.availableIcons.firstWhere(
        (opt) =>
            opt.isSvg
                ? opt.svgPath == existing.svgAsset
                : opt.codePoint == existing.iconCodePoint,
        orElse: () => WaterVessel.availableIcons.first,
      );
    } else {
      _selectedOption = WaterVessel.availableIcons.first;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.existing == null ? 'Add vessel' : 'Edit vessel'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Stanley cup',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _mlCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Size',
                suffix: Text('ml'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('Icon', style: theme.textTheme.labelMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: WaterVessel.availableIcons.map((opt) {
                final selected = opt.isSvg
                    ? opt.svgPath == _selectedOption.svgPath
                    : opt.codePoint == _selectedOption.codePoint;
                return Tooltip(
                  message: opt.label,
                  child: InkWell(
                    onTap: () => setState(() => _selectedOption = opt),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: selected
                            ? theme.colorScheme.primaryContainer
                            : theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: selected
                            ? Border.all(
                                color: theme.colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: Center(
                        child: opt.isSvg
                            ? SvgPicture.asset(
                                opt.svgPath!,
                                width: 24,
                                height: 24,
                                colorFilter: ColorFilter.mode(
                                  selected
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                  BlendMode.srcIn,
                                ),
                              )
                            : Icon(
                                opt.iconData,
                                color: selected
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final ml = int.tryParse(_mlCtrl.text);
            if (name.isEmpty || ml == null || ml <= 0) return;
            final vessel = WaterVessel(
              id: widget.existing?.id ?? const Uuid().v4(),
              name: name,
              ml: ml,
              iconCodePoint: _selectedOption.codePoint,
              svgAsset:
                  _selectedOption.isSvg ? _selectedOption.svgPath : null,
            );
            Navigator.pop(context, vessel);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
