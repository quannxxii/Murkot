import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_strings.dart';
import '../models/profile_wallpaper.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/blacklist_service.dart';
import '../services/settings_service.dart';
import '../utils/admin.dart';
import '../utils/helpers.dart';
import '../utils/profile_deep_link.dart';
import '../services/billing_service.dart';
import '../models/plus_cosmetics.dart';
import '../widgets/avatar_display.dart';
import 'hr_office_screen.dart';
import '../widgets/confirm_dialogs.dart';
import '../widgets/dev_card.dart';
import '../widgets/dev_status_badge.dart';
import '../widgets/image_crop_dialog.dart';
import '../widgets/murkot_toast.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/plus_features_panel.dart';
import '../widgets/unlumen/murkot_fx.dart';
import 'admin_panel_screen.dart';
import 'offer_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.authService,
    required this.settingsService,
    required this.blacklistService,
  });

  final AuthService authService;
  final SettingsService settingsService;
  final BlacklistService blacklistService;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _statusController = TextEditingController();
  final _statusFocusNode = FocusNode();
  final _picker = ImagePicker();

  bool _isSavingStatus = false;
  bool _isUpdatingAvatar = false;

  final _billing = BillingService();

  @override
  void initState() {
    super.initState();
    _statusController.text = widget.authService.currentUser?.status ?? '';
    final u = widget.authService.currentUser;
    if (u != null) {
      _billing.syncFromProfile(plus: u.isPlus, until: u.plusUntil);
    }
  }

  @override
  void dispose() {
    _statusFocusNode.dispose();
    _statusController.dispose();
    super.dispose();
  }

  void _showMessage(String text) {
    if (!mounted) return;
    MurkotToast.show(context, text);
  }

  Future<void> _showAvatarOptions() async {
    final strings = context.strings;
    final hasAvatar = widget.authService.currentUser?.avatarPath != null;
    final isPlus =
        widget.authService.currentUser?.isPlus == true || _billing.isPlus;

    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(strings.gallery),
              onTap: () => Navigator.pop(context, _AvatarAction.gallery),
            ),
            if (isPlus)
              ListTile(
                leading: const Icon(Icons.gif_box_outlined),
                title: Text(strings.isRu ? 'Гиф-аватар (Plus)' : 'GIF avatar (Plus)'),
                subtitle: Text(
                  strings.isRu ? 'Загрузить анимированный GIF' : 'Upload animated GIF',
                ),
                onTap: () => Navigator.pop(context, _AvatarAction.gif),
              ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(strings.camera),
              onTap: () => Navigator.pop(context, _AvatarAction.camera),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_emotions_outlined),
              title: Text(strings.chooseEmoji),
              onTap: () => Navigator.pop(context, _AvatarAction.emoji),
            ),
            if (hasAvatar)
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text(strings.removeAvatar,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () => Navigator.pop(context, _AvatarAction.remove),
              ),
          ],
        ),
      ),
    );

    if (action == null || !mounted) return;

    switch (action) {
      case _AvatarAction.gallery:
        await _pickAndSaveAvatar(ImageSource.gallery);
      case _AvatarAction.gif:
        await _pickAndSaveGifAvatar();
      case _AvatarAction.camera:
        await _pickAndSaveAvatar(ImageSource.camera);
      case _AvatarAction.emoji:
        await _pickEmojiAvatar();
      case _AvatarAction.remove:
        await _removeAvatar();
    }
  }

  Future<void> _pickAndSaveGifAvatar() async {
    if (!(widget.authService.currentUser?.isPlus == true || _billing.isPlus)) {
      _showMessage(context.strings.isRu
          ? 'Гиф-аватар доступен в Murkot Plus'
          : 'GIF avatar needs Murkot Plus');
      return;
    }
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    final name = file.name.toLowerCase();
    final isGif = name.endsWith('.gif') ||
        (bytes.length > 6 &&
            bytes[0] == 0x47 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46);
    if (!isGif) {
      _showMessage(context.strings.isRu
          ? 'Выбери файл .gif'
          : 'Please pick a .gif file');
      return;
    }
    setState(() => _isUpdatingAvatar = true);
    final error = await widget.authService.updateAvatarBytes(bytes);
    if (!mounted) return;
    setState(() => _isUpdatingAvatar = false);
    _showMessage(error ??
        (context.strings.isRu ? 'Гиф-аватар обновлён' : 'GIF avatar updated'));
  }

  Future<void> _pickEmojiAvatar() async {
    final strings = context.strings;
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  strings.chooseEmoji,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            Flexible(
              child: GridView.count(
                crossAxisCount: 6,
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  for (final e in _kAvatarEmojiChoices)
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.pop(context, e),
                      child: Center(
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (emoji == null || !mounted) return;

    setState(() => _isUpdatingAvatar = true);
    final error = await widget.authService.updateAvatarEmoji(emoji);
    if (!mounted) return;
    setState(() => _isUpdatingAvatar = false);
    _showMessage(error ?? context.strings.avatarUpdated);
  }

  Future<void> _pickAndSaveAvatar(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      imageQuality: 92,
    );
    if (file == null || !mounted) return;

    final raw = await file.readAsBytes();
    if (!mounted) return;
    final bytes = await showImageCropDialog(context, bytes: raw);
    if (bytes == null || !mounted) return;

    setState(() => _isUpdatingAvatar = true);
    final error = await widget.authService.updateAvatarBytes(bytes);
    if (!mounted) return;
    setState(() => _isUpdatingAvatar = false);
    _showMessage(error ?? context.strings.avatarUpdated);
  }

  Future<void> _removeAvatar() async {
    setState(() => _isUpdatingAvatar = true);
    await widget.authService.removeAvatar();
    if (!mounted) return;
    setState(() => _isUpdatingAvatar = false);
    _showMessage(context.strings.avatarRemoved);
  }

  Future<void> _saveStatus({bool showSnackBar = true}) async {
    if (_isSavingStatus) return;
    final currentStatus = widget.authService.currentUser?.status ?? '';
    if (_statusController.text.trim() == currentStatus) return;

    setState(() => _isSavingStatus = true);
    final error = await widget.authService.updateStatus(_statusController.text);
    if (!mounted) return;
    setState(() => _isSavingStatus = false);

    if (error != null) {
      _showMessage(error);
      return;
    }
    _statusController.text = widget.authService.currentUser?.status ?? '';
    if (showSnackBar) _showMessage(context.strings.statusSaved);
  }

  Future<void> _copyProfileLink() async {
    final login = widget.authService.currentUser?.login;
    if (login == null) return;
    final url = buildPublicProfileUrl(login);
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    _showMessage(context.strings.profileLinkCopied);
  }

  Future<void> _changeLogin() async {
    final strings = context.strings;
    final newLogin = await showTextInputDialog(
      context: context,
      title: strings.changeName,
      hint: strings.changeNameHint,
      initialValue: widget.authService.currentUser!.login,
      validator: (v) => v == null || v.trim().isEmpty ? strings.nameRequired : null,
    );
    if (newLogin == null || !mounted) return;
    final error = await widget.authService.changeLogin(newLogin);
    _showMessage(error ?? strings.nameChanged);
  }

  Future<void> _changeEmail() async {
    final strings = context.strings;
    final newEmail = await showTextInputDialog(
      context: context,
      title: strings.changeEmail,
      hint: strings.changeEmailHint,
      initialValue: widget.authService.currentUser!.email,
      keyboardType: TextInputType.emailAddress,
      validator: (v) => v == null || !v.contains('@') ? strings.nameRequired : null,
    );
    if (newEmail == null || !mounted) return;

    final password = await showTextInputDialog(
      context: context,
      title: strings.passwordHint,
      hint: strings.passwordHint,
      obscureText: true,
      validator: (v) => v == null || v.isEmpty ? strings.passwordRequired : null,
    );
    if (password == null || !mounted) return;

    final error = await widget.authService.changeEmail(newEmail, password);
    _showMessage(error ?? strings.emailChanged);
  }

  Future<void> _pickBirthday() async {
    final user = widget.authService.currentUser!;
    final picked = await showDatePicker(
      context: context,
      initialDate: user.birthday ?? DateTime(2000, 1, 1),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      locale: widget.settingsService.locale,
    );
    if (picked != null) {
      final error = await widget.authService.updateBirthday(picked);
      if (!mounted) return;
      if (error != null) _showMessage(error);
    }
  }

  Future<void> _buyHr() async {
    final ok = await showPaymentSheet(
      context,
      product: MurkotProduct.hrOffice,
      billing: _billing,
    );
    if (!mounted) return;
    if (ok) setState(() {});
  }

  Future<void> _editDevCard() async {
    final saved = await showDevCardEditSheet(
      context: context,
      authService: widget.authService,
    );
    if (saved == true && mounted) {
      _showMessage(context.strings.devCardSaved);
    }
  }

  Future<void> _pickWallpaper() async {
    final strings = context.strings;
    final currentId = widget.authService.currentUser?.profileWallpaperId ?? 'blue';

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(strings.chooseWallpaper,
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: ProfileWallpaper.presets.map((wallpaper) {
                  final isSelected = wallpaper.id == currentId &&
                      widget.authService.currentUser?.customWallpaperPath == null;
                  return GestureDetector(
                    onTap: () async {
                      await widget.authService.updateWallpaper(wallpaper.id);
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected
                                ? Border.all(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 3)
                                : null,
                          ),
                          child: ProfileWallpaperSurface(
                            wallpaper: wallpaper,
                            borderRadius: BorderRadius.circular(12),
                            ornamentSize: 40,
                            ornamentOpacity: 0.55,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(wallpaper.name, style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const Divider(height: 24),
              ListTile(
                leading: const Icon(Icons.upload_outlined),
                title: Text(strings.uploadWallpaper),
                onTap: () async {
                  Navigator.pop(context);
                  final file = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1600,
                    imageQuality: 85,
                  );
                  if (file == null || !mounted) return;
                  final bytes = await file.readAsBytes();
                  final error =
                      await widget.authService.updateCustomWallpaperBytes(bytes);
                  _showMessage(error ?? strings.avatarUpdated);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final strings = context.strings;
    final confirmed = await showConfirmDialog(
      context: context,
      title: strings.logoutTitle,
      message: strings.logoutMessage,
      confirmLabel: strings.confirmLogout,
    );
    if (confirmed == true) await widget.authService.logout();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDeleteAccountDialog(context);
    if (!confirmed || !mounted) return;
    final error = await widget.authService.deleteAccount();
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SettingsScreen(
          settingsService: widget.settingsService,
          blacklistService: widget.blacklistService,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isNarrow = screenWidth < 720;

    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.authService,
        widget.settingsService,
      ]),
      builder: (context, _) {
        final current = widget.authService.currentUser!;
        _billing.syncFromProfile(plus: current.isPlus, until: current.plusUntil);
        final wallpaper = ProfileWallpaper.byId(current.profileWallpaperId);
        final customPath = current.customWallpaperPath;
        final isNetworkWallpaper = customPath != null &&
            (customPath.startsWith('http://') ||
                customPath.startsWith('https://'));
        final hasCustomWallpaper =
            isNetworkWallpaper || localPathExists(customPath);

        // Same structure as stranger profile: wallpaper + avatar on top,
        // fields below. Full-width on desktop (not a narrow centered column).
        final avatarRadius = isNarrow
            ? (screenWidth * 0.36).clamp(120.0, 176.0)
            : 96.0;
        final avatarSize = avatarRadius * 2;
        final wallpaperHeight = math.max(
          avatarSize * 1.55,
          MediaQuery.sizeOf(context).height * (isNarrow ? 0.34 : 0.38),
        );

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: wallpaperHeight,
                width: double.infinity,
                child: _wallpaperStack(
                  context,
                  theme,
                  strings,
                  current,
                  wallpaper,
                  customPath,
                  isNetworkWallpaper,
                  hasCustomWallpaper,
                  avatarRadius,
                  avatarSize,
                  wallpaperHeight,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: theme.colorScheme.surface,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    isNarrow ? 16 : 32,
                    16,
                    isNarrow ? 16 : 32,
                    20 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            strings.changeAvatarHint,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _profileFields(context, strings, theme, current),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Wallpaper + avatar stack (full-bleed header).
  Widget _wallpaperStack(
    BuildContext context,
    ThemeData theme,
    AppStrings strings,
    User current,
    ProfileWallpaper wallpaper,
    String? customPath,
    bool isNetworkWallpaper,
    bool hasCustomWallpaper,
    double avatarRadius,
    double avatarSize,
    double wallpaperHeight,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: customPath == null || !hasCustomWallpaper
              ? ProfileWallpaperSurface(
                  wallpaper: wallpaper,
                  ornamentSize: 220,
                  ornamentOpacity: 0.28,
                )
              : (isNetworkWallpaper
                  ? Image.network(customPath, fit: BoxFit.cover)
                  : Image.file(File(customPath), fit: BoxFit.cover)),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 4,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MurkotFloatingTooltip(
                message: strings.copyProfileLink,
                child: IconButton(
                  icon: const Icon(Icons.link),
                  tooltip: '',
                  onPressed: _copyProfileLink,
                ),
              ),
              if (isMurkotAdminLogin(current.login))
                MurkotFloatingTooltip(
                  message: strings.adminTitle,
                  child: IconButton(
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    tooltip: '',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminPanelScreen(
                            currentLogin: current.login,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              MurkotFloatingTooltip(
                message: strings.settingsTitle,
                child: IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: '',
                  onPressed: _openSettings,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: (wallpaperHeight - avatarSize) / 2,
          left: 0,
          right: 0,
          child: Center(
            child: _AvatarSection(
              avatarPath: current.avatarPath,
              avatarEmoji: current.avatarEmoji,
              login: current.login,
              nickColorId: current.nickColorId,
              frame: current.avatarFrame,
              showPlusBadge: current.isPlus || _billing.isPlus,
              devStatus: current.devStatus,
              isLoading: _isUpdatingAvatar,
              hint: strings.changeAvatarHint,
              onTap: _isUpdatingAvatar ? null : _showAvatarOptions,
              onLoginTap: _changeLogin,
              forceRadius: avatarRadius,
              compact: true,
            ),
          ),
        ),
        Positioned(
          top: (wallpaperHeight - avatarSize) / 2 + avatarSize + 8,
          left: 16,
          right: 16,
          child: Column(
            children: [
              InkWell(
                onTap: _changeLogin,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      current.login,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: nickColorFromId(current.nickColorId),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_outlined,
                        size: 16,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7)),
                  ],
                ),
              ),
              if (current.devStatus != DevStatus.none) ...[
                const SizedBox(height: 8),
                DevStatusBadge(status: current.devStatus, large: true),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileFields(
    BuildContext context,
    AppStrings strings,
    ThemeData theme,
    User current,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.settingsService.profileNudgeDismissed &&
            _profileFillScore(current) < 5) ...[
          const SizedBox(height: 20),
          _ProfileNudge(
            onDismiss: widget.settingsService.dismissProfileNudge,
          ),
        ],
        const SizedBox(height: 24),
        _ProfileField(
          icon: Icons.edit_outlined,
          label: strings.status,
          child: TextField(
            controller: _statusController,
            focusNode: _statusFocusNode,
            maxLength: 120,
            decoration: InputDecoration(
              hintText: strings.statusHint,
              counterText: '',
              suffixIcon: _isSavingStatus
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: MurkotLoaderCompact(),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.check),
                      onPressed: _saveStatus,
                    ),
            ),
            onSubmitted: (_) {
              _saveStatus();
              _statusFocusNode.unfocus();
            },
          ),
        ),
        const SizedBox(height: 16),
        _ProfileField(
          icon: Icons.email_outlined,
          label: strings.email,
          child: Column(
            children: [
              _ReadOnlyField(text: current.email),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _changeEmail,
                  child: Text(strings.changeEmail),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _ProfileField(
          icon: Icons.cake_outlined,
          label: strings.birthday,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              current.birthday != null
                  ? '${formatBirthday(current.birthday!)} (${strings.ageYears(calculateAge(current.birthday!))})'
                  : strings.notSet,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickBirthday,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _ProfileField(
          icon: Icons.work_outline,
          label: strings.devCardTitle,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DevCardView(user: current),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _editDevCard,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(strings.devCardEdit),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PlusFeaturesPanel(
          authService: widget.authService,
          billing: _billing,
          user: current,
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const OfferScreen(),
            ),
          ),
          child: Text(strings.isRu ? 'Оферта и реквизиты' : 'Offer & legal'),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.business_center,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Кабинет HR — 24 999 ₽/мес',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Безлимит поиск, бренд-профиль, Smart-подбор ИИ, рассылка до 20 кандидатов',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (!_billing.hasHrOffice)
                      FilledButton.tonalIcon(
                        onPressed: _buyHr,
                        icon: const Icon(Icons.workspace_premium_outlined,
                            size: 18),
                        label: Text(strings.isRu ? 'Оплатить' : 'Pay'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              HrOfficeScreen(billingService: _billing),
                        ),
                      ),
                      icon: const Icon(Icons.workspace_premium_outlined,
                          size: 18),
                      label: Text(strings.isRu
                          ? 'Открыть кабинет'
                          : 'Open office'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.wallpaper, color: theme.colorScheme.primary),
          title: Text(strings.chooseWallpaper),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pickWallpaper,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _logout,
          icon: Icon(Icons.logout, color: theme.colorScheme.error),
          label: Text(strings.logout,
              style: TextStyle(color: theme.colorScheme.error)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.5)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _deleteAccount,
          icon: Icon(Icons.delete_forever, color: theme.colorScheme.error),
          label: Text(strings.deleteAccount,
              style: TextStyle(color: theme.colorScheme.error)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 52),
            side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.5)),
          ),
        ),
      ],
    );
  }
}

int _profileFillScore(User user) {
  var score = 0;
  final status = user.status.trim();
  if (status.isNotEmpty &&
      status != 'В сети' &&
      status.toLowerCase() != 'online') {
    score++;
  }
  if (user.avatarPath != null && user.avatarPath!.isNotEmpty) score++;
  if (user.devStatus != DevStatus.none) score++;
  if (user.skills.length >= 2) score++;
  if ((user.city ?? '').trim().isNotEmpty) score++;
  if (user.experienceLevel != null) score++;
  if ((user.githubUrl ?? '').trim().isNotEmpty ||
      (user.portfolioUrl ?? '').trim().isNotEmpty) {
    score++;
  }
  return score;
}

class _ProfileNudge extends StatelessWidget {
  const _ProfileNudge({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  strings.profileNudgeTitle,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(strings.profileNudgeBody, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(
            tooltip: strings.profileNudgeDismiss,
            onPressed: onDismiss,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

enum _AvatarAction { gallery, camera, emoji, remove, gif }

/// Emoji available as profile avatars.
const _kAvatarEmojiChoices = [
  '🐱', '😺', '😸', '😻', '🐈', '🐈‍⬛',
  '🍊', '🍋', '🍑', '🥭', '🍍', '🥝',
  '😀', '😎', '🤩', '😇', '🥳', '🤗',
  '🦊', '🐶', '🐼', '🐨', '🦁', '🐯',
  '🌟', '🔥', '⚡', '🌈', '💎', '🍀',
  '🎮', '🎨', '🎵', '🚀', '🦄', '👑',
];

class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.avatarPath,
    required this.avatarEmoji,
    required this.login,
    required this.nickColorId,
    required this.frame,
    required this.showPlusBadge,
    required this.devStatus,
    required this.isLoading,
    required this.hint,
    required this.onTap,
    required this.onLoginTap,
    this.forceRadius,
    this.compact = false,
  });

  final String? avatarPath;
  final String? avatarEmoji;
  final String login;
  final String? nickColorId;
  final AvatarFrameId frame;
  final bool showPlusBadge;
  final DevStatus devStatus;
  final bool isLoading;
  final String hint;
  final VoidCallback? onTap;
  final VoidCallback onLoginTap;
  final double? forceRadius;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final radius = forceRadius ??
        (width < 720
            ? (width * 0.36).clamp(120.0, 176.0)
            : (width * 0.12).clamp(88.0, 120.0));
    final nickColor = nickColorFromId(nickColorId);
    final size = radius * 2;

    final avatar = Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                customBorder: const CircleBorder(),
                child: AvatarDisplay(
                  avatarPath: avatarPath,
                  avatarEmoji: avatarEmoji,
                  name: login,
                  radius: radius,
                  frame: frame,
                  showPlusBadge: showPlusBadge,
                ),
              ),
            ),
            if (isLoading)
              Container(
                width: size,
                height: size,
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: MurkotLoader(size: 36, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );

    if (compact) return avatar;

    return Column(
      children: [
        avatar,
        const SizedBox(height: 12),
        InkWell(
          onTap: onLoginTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  login,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: nickColor,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 16, color: theme.colorScheme.outline),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        if (devStatus != DevStatus.none) ...[
          const SizedBox(height: 10),
          DevStatusBadge(status: devStatus, large: true),
        ],
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
