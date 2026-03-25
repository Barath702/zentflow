import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zentflow/models/app_theme_mode.dart';
import 'package:zentflow/models/transfer_item.dart';
import 'package:zentflow/ui/providers/app_providers.dart';
import 'package:zentflow/ui/design/app_colors.dart';
import 'package:zentflow/ui/design/app_theme.dart';

class ZentApp extends ConsumerWidget {
  const ZentApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Zent',
      theme: AppTheme.fromMode(state.themeMode),
      home: const HomeShell(),
    );
  }
}

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _clipboardController = TextEditingController();
  final _deviceController = TextEditingController();

  @override
  void dispose() {
    _clipboardController.dispose();
    _deviceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final actions = ref.read(appControllerProvider.notifier);
    _deviceController.text = state.deviceName;
    final pages = [
      _DiscoverPage(onSendFile: actions.pickAndSendFile),
      const _TransfersPage(),
      _ClipboardPage(
        controller: _clipboardController,
        onSend: () {
          actions.sendClipboardText(_clipboardController.text);
          _clipboardController.clear();
        },
      ),
      const _StatsPage(),
      _SettingsPage(
        deviceController: _deviceController,
        onDeviceNameChanged: actions.setDeviceName,
      ),
    ];

    return Scaffold(
      body: Stack(
        children: [
          _BackgroundGlow(mode: state.themeMode),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 16),
                        const _BrandHeader(),
                        const SizedBox(height: 12),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            child: KeyedSubtree(
                              key: ValueKey(state.currentTab),
                              child: pages[state.currentTab],
                            ),
                          ),
                        ),
                        const SizedBox(height: 104),
                      ],
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: _BottomBar(
                          index: state.currentTab,
                          onTap: actions.setTab,
                          mode: state.themeMode,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverPage extends ConsumerWidget {
  const _DiscoverPage({required this.onSendFile});

  final Future<void> Function() onSendFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final actions = ref.read(appControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (state.isConnected)
          _GlassCard(
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFF1E2032),
                    child: Icon(Icons.phone_android_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected to ${state.connectedDeviceName ?? 'Device'}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: AppColors.success),
                          SizedBox(width: 6),
                          Text('Online'),
                        ],
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: actions.disconnectCurrent,
                  child: const Text('Disconnect'),
                ),
              ],
            ),
          )
        else if (state.devices.isEmpty)
          const _GlassCard(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('Waiting for local devices...')),
            ),
          )
        else
          Column(
            children: [
              for (final device in state.devices) ...[
                _DeviceCard(
                  deviceName: device.name,
                  selected: state.selectedDevice?.peerId == device.peerId,
                  onTap: () => actions.connectToDevice(device),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: !state.isConnected || state.selectedDevice == null ? null : onSendFile,
          child: _GlassCard(
            child: SizedBox(
              height: 240,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_rounded, size: 44, color: AppColors.primary),
                    const SizedBox(height: 10),
                    Text(
                      state.isSendingNow
                          ? 'Sending to ${state.selectedDevice?.name ?? 'device'}'
                          : (!state.isConnected ? 'Select a device first' : 'Drop files here'),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      !state.isConnected ? 'Tap a device above' : 'Tap here to pick and send',
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TransfersPage extends ConsumerWidget {
  const _TransfersPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(appControllerProvider.select((s) => s.transfers));
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 52, color: Theme.of(context).textTheme.bodySmall?.color),
            const SizedBox(height: 10),
            const Text('No transfers yet', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700)),
            Text(
              'Drop files in the Drop Zone to start',
              style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => ref.read(appControllerProvider.notifier).addMoreFiles(),
              icon: const Icon(Icons.add),
              label: const Text('Add More Files'),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemBuilder: (_, i) => _TransferCard(item: transfers[i]),
            separatorBuilder: (_, index) => SizedBox(height: 10 + (index * 0.0)),
            itemCount: transfers.length,
          ),
        ),
      ],
    );
  }
}

class _ClipboardPage extends ConsumerWidget {
  const _ClipboardPage({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(appControllerProvider.select((s) => s.clipboardHistory));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _GlassCard(
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: TextStyle(
                    fontSize: 20,
                    color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type or paste to share...',
                    hintStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: IconButton(
                  onPressed: onSend,
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...history.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _GlassCard(
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF3A2A6C),
                    child: Text(
                      item.fromDevice.isNotEmpty ? item.fromDevice.trim()[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.text, style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          'from ${item.fromDevice} · ${_hhmm(item.timestamp)}',
                          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: item.text));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied')),
                        );
                      }
                    },
                    icon: Icon(Icons.copy_rounded, color: Theme.of(context).textTheme.bodySmall?.color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatsPage extends ConsumerWidget {
  const _StatsPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transfers = ref.watch(appControllerProvider.select((s) => s.transfers));
    final done = transfers.where((t) => t.status == TransferStatus.done).toList();
    final filesTransferred = done.length;
    final dataShared = done.fold<int>(0, (p, e) => p + e.bytesTotal);
    final peakSpeed = transfers.fold<double>(0, (p, e) => max(p, e.speedBytesPerSec));
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        const Text('Nerd Stats 🤓', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            _StatCard(
              icon: Icons.description_outlined,
              title: 'Files Transferred',
              value: '$filesTransferred',
              gradient: AppColors.gradientPrimary,
            ),
            _StatCard(
              icon: Icons.storage_rounded,
              title: 'Data Shared',
              value: _fmtBytes(dataShared),
              gradient: AppColors.gradientAccent,
            ),
            _StatCard(
              icon: Icons.trending_up_rounded,
              title: 'Data Saved',
              value: _fmtBytes((dataShared * 0.1).round()),
              gradient: AppColors.gradientWarm,
            ),
            _StatCard(
              icon: Icons.bolt_rounded,
              title: 'Peak Speed',
              value: '${_fmtBytes(peakSpeed.round())}/s',
              gradient: AppColors.gradientPrimary,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _GlassCard(
          child: Text(
            'All transfers happen locally — no internet data used!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
          ),
        ),
      ],
    );
  }
}

class _SettingsPage extends ConsumerWidget {
  const _SettingsPage({
    required this.deviceController,
    required this.onDeviceNameChanged,
  });

  final TextEditingController deviceController;
  final ValueChanged<String> onDeviceNameChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    final actions = ref.read(appControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Device Name', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('How others see you', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
              const SizedBox(height: 10),
              TextField(
                controller: deviceController,
                onChanged: onDeviceNameChanged,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white,
                ),
                decoration: const InputDecoration(border: InputBorder.none),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassCard(
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: AppColors.gradientAccent,
                ),
                child: const Icon(Icons.folder_rounded, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Download Location', style: TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      state.downloadDir ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              OutlinedButton(
                onPressed: actions.chooseDownloadDir,
                child: const Text('Change Folder'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Connected Devices', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...state.devices.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, color: AppColors.success, size: 9),
                      const SizedBox(width: 8),
                      Text(d.name),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Row(
                children: [
                  _ThemeChip(
                    label: 'Light',
                    active: state.themeMode == AppThemeMode.light,
                    onTap: () => actions.setTheme(AppThemeMode.light),
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    label: 'Dark',
                    active: state.themeMode == AppThemeMode.dark,
                    onTap: () => actions.setTheme(AppThemeMode.dark),
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    label: 'AMOLED',
                    active: state.themeMode == AppThemeMode.amoled,
                    onTap: () => actions.setTheme(AppThemeMode.amoled),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _GlassCard(
          child: SwitchListTile.adaptive(
            value: state.warpSpeed,
            onChanged: actions.toggleWarp,
            title: const Text('Warp Speed 🚀'),
            subtitle: const Text('Multi-threaded transfer'),
          ),
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.index, required this.onTap, required this.mode});

  final int index;
  final ValueChanged<int> onTap;
  final AppThemeMode mode;

  @override
  Widget build(BuildContext context) {
    final items = const [
      Icons.radar_rounded,
      Icons.swap_vert_rounded,
      Icons.content_paste_rounded,
      Icons.bar_chart_rounded,
      Icons.settings_rounded,
    ];
    final isLight = Theme.of(context).brightness == Brightness.light;
    return SizedBox(
      width: 372,
      child: _GlassCard(
        radius: 28,
        blurSigma: 6,
        child: LayoutBuilder(
          builder: (context, c) {
            final tabW = c.maxWidth / items.length;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: tabW * index,
                  top: 0,
                  bottom: 0,
                  width: tabW,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: isLight
                          ? const LinearGradient(colors: [Color(0xFF7A4DFF), Color(0xFF2D8CFF)])
                          : const LinearGradient(colors: [Color(0x6A7A4DFF), Color(0x6A2D8CFF)]),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: IconButton(
                          onPressed: () => onTap(i),
                          icon: Icon(
                            items[i],
                            size: 22,
                            color: i == index
                                ? Colors.white
                                : (isLight ? const Color(0xFF4B5563) : AppColors.mutedForegroundDark),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({
    required this.child,
    this.radius = 22,
    this.blurSigma = 10,
  });

  final Widget child;
  final double radius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: isLight
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: AppColors.cardLight.withValues(alpha: 0.78),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 24,
                      offset: Offset(0, 14),
                    ),
                  ],
                  border: Border.all(color: const Color(0x0A000000)),
                ),
                child: child,
              ),
            )
          : BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: child,
              ),
            ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.item});

  final TransferItem item;

  @override
  Widget build(BuildContext context) {
    final done = item.status == TransferStatus.done;
    final cancelled = item.status == TransferStatus.cancelled;
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: item.direction == TransferDirection.send ? const Color(0xFF5A48C7) : const Color(0xFF2C89FF),
                child: Icon(item.direction == TransferDirection.send ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(
                      '${_fmtBytes(item.bytesTotal)} ${item.direction == TransferDirection.send ? '->' : '<-'} ${item.peerName}',
                      style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ],
                ),
              ),
              Icon(
                done
                    ? Icons.check_rounded
                    : (cancelled ? Icons.close_rounded : Icons.timelapse_rounded),
                color: done
                    ? AppColors.success
                    : (cancelled ? AppColors.destructive : Theme.of(context).textTheme.bodySmall?.color),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: item.progress.clamp(0, 1)),
          const SizedBox(height: 4),
          Text(
            '${(item.progress * 100).toStringAsFixed(0)}% · ${_fmtBytes(item.speedBytesPerSec.round())}/s',
            style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
          ),
          if (item.canControl) ...[
            const SizedBox(height: 10),
            _TransferControls(item: item),
          ],
        ],
      ),
    );
  }
}

class _TransferControls extends ConsumerWidget {
  const _TransferControls({required this.item});
  final TransferItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.read(appControllerProvider.notifier);
    if (item.status == TransferStatus.done) {
      return const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success),
          SizedBox(width: 8),
          Text('Completed', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
    }
    if (item.status == TransferStatus.cancelled) {
      return const Row(
        children: [
          Icon(Icons.close_rounded, color: AppColors.destructive),
          SizedBox(width: 8),
          Text('Cancelled', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
    }
    if (item.status == TransferStatus.failed) {
      return const Row(
        children: [
          Icon(Icons.close_rounded, color: AppColors.destructive),
          SizedBox(width: 8),
          Text('Failed', style: TextStyle(fontWeight: FontWeight.w700)),
        ],
      );
    }
    final isPaused = item.status == TransferStatus.paused;
    final isActive = item.status == TransferStatus.sending || item.status == TransferStatus.receiving || isPaused;
    final canPauseResume = isActive && item.status != TransferStatus.done && item.status != TransferStatus.cancelled;
    final isReceiving = item.direction == TransferDirection.receive;
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            onPressed: !canPauseResume
                ? null
                : () => isPaused
                    ? (isReceiving ? actions.resumeIncomingTransfer(item.id) : actions.resumeTransfer(item.id))
                    : (isReceiving ? actions.pauseIncomingTransfer(item.id) : actions.pauseTransfer(item.id)),
            child: Text(isPaused ? 'Resume' : 'Pause'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: item.status == TransferStatus.done || item.status == TransferStatus.cancelled
                ? null
                : () => isReceiving ? actions.cancelIncomingTransfer(item.id) : actions.cancelTransfer(item.id),
            child: const Text('Cancel'),
          ),
        ),
      ],
    );
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: active ? AppColors.gradientPrimary : null,
            color: active
                ? null
                : (Theme.of(context).brightness == Brightness.light
                    ? AppColors.mutedLight
                    : Colors.white.withValues(alpha: 0.03)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.gradient,
  });

  final IconData icon;
  final String title;
  final String value;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: gradient,
            ),
            child: Icon(icon, color: Colors.white),
          ),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showStatusText = constraints.maxWidth >= 360;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Zent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.nunitoSans(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        foreground: Paint()
                          ..shader = const LinearGradient(
                            colors: [
                              Color(0xFF7C3AED),
                              Color(0xFF0EA5E9),
                              Color(0xFFEC4899),
                              Color(0xFFF59E0B),
                            ],
                          ).createShader(const Rect.fromLTWH(0, 0, 260, 64)),
                        shadows: [
                          Shadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Local file sharing',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, color: AppColors.success, size: 12),
                  if (showStatusText) const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow({required this.mode});

  final AppThemeMode mode;

  @override
  Widget build(BuildContext context) {
    if (mode == AppThemeMode.light) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFFF7F8FC),
              const Color(0xFFF3F4FF),
              const Color(0xFFF7F8FC),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: -140,
              top: -120,
              child: Container(
                width: 360,
                height: 360,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x336B45FF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -160,
              top: 40,
              child: Container(
                width: 420,
                height: 420,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0x332D8CFF),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox.expand(),
          ],
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            mode == AppThemeMode.amoled ? Colors.black : AppColors.backgroundDark,
            mode == AppThemeMode.amoled ? Colors.black : AppColors.backgroundDark,
            mode == AppThemeMode.amoled ? AppColors.backgroundAmoled : AppColors.backgroundDark,
            const Color(0xFF0E0D2A).withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -40,
            child: Container(
              width: 200,
              height: 220,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: -80,
            bottom: -100,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.deviceName,
    required this.selected,
    required this.onTap,
  });

  final String deviceName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: isLight ? AppColors.cardLight : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : (isLight ? const Color(0x14000000) : Colors.white.withValues(alpha: 0.08)),
            width: 1.1,
          ),
          boxShadow: selected
              ? (isLight
                  ? const [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 18, offset: Offset(0, 10)),
                    ]
                  : [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 22)])
              : (isLight
                  ? const [
                      BoxShadow(color: Color(0x12000000), blurRadius: 12, offset: Offset(0, 8)),
                    ]
                  : null),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFF1E2032),
                  child: Icon(Icons.phone_android_rounded, color: Colors.white),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                deviceName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmtBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}

String _hhmm(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
