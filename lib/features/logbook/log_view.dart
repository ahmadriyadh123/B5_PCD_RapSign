import 'package:flutter/material.dart';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:logbook_app_001/features/auth/login_view.dart';
import 'package:logbook_app_001/features/logbook/log_controller.dart';
import 'package:logbook_app_001/features/logbook/log_editor_page.dart';
import 'package:logbook_app_001/features/logbook/models/log_model.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';
import 'package:logbook_app_001/services/access_policy.dart';
import 'package:logbook_app_001/services/mongo_service.dart';

class LogView extends StatefulWidget {
  final String username;
  final String teamId;
  final String role;

  const LogView({
    super.key,
    required this.username,
    required this.teamId,
    this.role = 'Anggota',
  });

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late final LogController _controller;
  bool _isLoading = true;
  bool _isOffline = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _controller = LogController(
      username: widget.username,
      teamId: widget.teamId,
      role: widget.role,
    );
    // Harus initAsync dulu sebelum loadLogs
    Future.microtask(() async {
      await _controller.initAsync();
      await _initDatabase();
      _listenConnectivity();
    });
  }

  void _listenConnectivity() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final hasInternet = !results.contains(ConnectivityResult.none);
      if (!hasInternet) {
        if (mounted) setState(() => _isOffline = true);
        return;
      }

      try {
        await MongoService().connect();
        await _controller.syncPendingLocalLogs();
        await _controller.loadLogs(widget.teamId);

        if (mounted) {
          setState(() => _isOffline = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('Koneksi kembali: data lokal disinkronkan ke Cloud'),
              backgroundColor: Color(0xFF8A6F4D),
            ),
          );
        }
      } catch (_) {
        if (mounted) setState(() => _isOffline = true);
      }
    });
  }

  Future<void> _initDatabase() async {
    setState(() => _isLoading = true);
    try {
      await MongoService().connect().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Koneksi Cloud Timeout'),
          );

      await _controller.loadLogs(widget.teamId);
      if (mounted) setState(() => _isOffline = false);
    } catch (e) {
      if (mounted) setState(() => _isOffline = true);
      await LogHelper.writeLog(
        'UI: Error init database - $e',
        source: 'log_view.dart',
        level: 1,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onRefresh() async {
    try {
      await MongoService().connect().timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Timeout saat refresh'),
          );
      await _controller.loadLogs(widget.teamId);
      if (mounted) setState(() => _isOffline = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data berhasil diperbarui dari Cloud'),
            backgroundColor: Color(0xFF8A6F4D),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isOffline = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal refresh: Masih offline'),
            backgroundColor: Color(0xFF9E5A5A),
          ),
        );
      }
    }
  }

  void _goToEditor({LogModel? log, int? index}) {
    if (log != null && !AccessPolicy.isSameTeam(widget.teamId, log.teamId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan ini bukan dari tim Anda.'),
          backgroundColor: Color(0xFF9E5A5A),
        ),
      );
      return;
    }

    if (log != null &&
        !AccessPolicy.canModifyLog(
          currentUserId: (_controller.currentUser['id'] ?? '').toString(),
          logAuthorId: log.authorId,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hanya pemilik catatan yang boleh mengedit.'),
          backgroundColor: Color(0xFF9E5A5A),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LogEditorPage(
          log: log,
          index: index,
          controller: _controller,
          currentUser: _controller.currentUser,
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginView()),
                (route) => false,
              );
            },
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(color: Color(0xFF9E5A5A)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Ini adalah bagian tombol yang berada di sisi kanan atas, yang berfungsi untuk membuka kamera dan verifikasi tanda tangan. Kita menggunakan IconButton dengan ikon kamera dan draw_rounded untuk membedakan fungsi keduanya. Ketika tombol kamera ditekan, kita navigasi ke VisionView, sedangkan tombol draw_rounded akan membuka SignatureVerificationView dengan membawa username sebagai parameter.
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final canCreate = AccessPolicy.canPerform(
      widget.role,
      AccessPolicy.actionCreate,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logbook: ${widget.username}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(
                  widget.role == AccessPolicy.roleKetua
                      ? Icons.shield
                      : widget.role == AccessPolicy.roleReviewer
                          ? Icons.rule
                          : Icons.person,
                  size: 12,
                  color: widget.role == AccessPolicy.roleKetua
                      ? const Color(0xFFFFD700)
                      : Colors.white70,
                ),
                const SizedBox(width: 4),
                Text(
                  AccessPolicy.labelFor(widget.role),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: colorScheme.primary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _confirmLogout,
          ),
        ],
      ),
      body: ValueListenableBuilder<List<LogModel>>(
        valueListenable: _controller.logsNotifier,
        builder: (context, currentLogs, child) {
          final currentUserId =
              (_controller.currentUser['id'] ?? '').toString();
          final currentTeamId =
              (_controller.currentUser['teamId'] ?? widget.teamId).toString();

          final teamLogs = currentLogs
              .where((log) => AccessPolicy.canViewLog(
                    currentUserId: currentUserId,
                    logAuthorId: log.authorId,
                    isPublic: log.isPublic,
                    currentUserTeamId: currentTeamId,
                    logTeamId: log.teamId,
                  ))
              .toList();

          final displayLogs = teamLogs.where((log) {
            if (_searchQuery.trim().isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return log.title.toLowerCase().contains(q) ||
                log.description.toLowerCase().contains(q);
          }).toList();

          if (_isLoading) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF9E5A5A)),
                  SizedBox(height: 12),
                  Text('Memuat logbook...'),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _searchQuery = value),
                  decoration: InputDecoration(
                    hintText: 'Cari judul atau isi markdown...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                ),
              ),
              if (_isOffline)
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  color: const Color(0xFFC2A35C),
                  child: const Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Offline Mode: menampilkan cache lokal.',
                          style: TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: const Color(0xFF9E5A5A),
                  child: displayLogs.isEmpty
                      ? ListView(
                          children: [
                            SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.22),
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.note_alt_outlined,
                                    size: 64,
                                    color: Color(0xFF8B7D6B),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Belum ada aktivitas hari ini?',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Mulai catat kemajuan proyek Anda!',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  const SizedBox(height: 12),
                                  if (canCreate)
                                    ElevatedButton(
                                      onPressed: () => _goToEditor(),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF8A6F4D),
                                        foregroundColor:
                                            const Color(0xFFF3EBDD),
                                      ),
                                      child: const Text('Buat Catatan Pertama'),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          itemCount: displayLogs.length,
                          itemBuilder: (context, index) {
                            final log = displayLogs[index];
                            final currentUser = _controller.currentUser;
                            final bool isOwner =
                                log.authorId == currentUser['id'];
                            final bool sameTeam = AccessPolicy.isSameTeam(
                              widget.teamId,
                              log.teamId,
                            );

                            final canEdit = sameTeam && isOwner;
                            final canDelete = sameTeam && isOwner;

                            final catColor = categoryColors[log.category] ??
                                const Color(0xFF8B7D6B);
                            final catBg = categoryBgColors[log.category] ??
                                const Color(0xFFF5EFE8);
                            final catIcon =
                                categoryIcons[log.category] ?? Icons.category;
                            final catLabel = categoryLabels[log.category] ??
                                log.category.name;

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Left color accent bar
                                    Container(
                                      width: 5,
                                      decoration: BoxDecoration(
                                        color: catColor,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          bottomLeft: Radius.circular(12),
                                        ),
                                      ),
                                    ),
                                    // Content
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            // Title row
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    log.title,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                // sync icon
                                                Icon(
                                                  log.isSynced
                                                      ? Icons.cloud_done
                                                      : Icons
                                                          .cloud_upload_outlined,
                                                  size: 16,
                                                  color: log.isSynced
                                                      ? const Color(0xFF8A6F4D)
                                                      : const Color(0xFF9E5A5A),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            // Description preview
                                            Text(
                                              log.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF6B6B6B),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            // Bottom row: category chip + date + actions
                                            Row(
                                              children: [
                                                // Category chip
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: catBg,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                    border: Border.all(
                                                        color: catColor
                                                            .withOpacity(0.4)),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(catIcon,
                                                          size: 12,
                                                          color: catColor),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        catLabel,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: catColor,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: log.isPublic
                                                        ? const Color(
                                                            0xFFE8F5E9)
                                                        : const Color(
                                                            0xFFFFEBEE),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            20),
                                                  ),
                                                  child: Text(
                                                    log.isPublic
                                                        ? 'Public'
                                                        : 'Private',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: log.isPublic
                                                          ? const Color(
                                                              0xFF2E7D32)
                                                          : const Color(
                                                              0xFFC62828),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                // Date
                                                Expanded(
                                                  child: Text(
                                                    LogHelper.formatRelative(
                                                        log.date),
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                  ),
                                                ),
                                                // Action buttons
                                                if (canEdit)
                                                  SizedBox(
                                                    height: 32,
                                                    width: 32,
                                                    child: IconButton(
                                                      padding: EdgeInsets.zero,
                                                      icon: const Icon(
                                                        Icons.edit,
                                                        size: 18,
                                                        color:
                                                            Color(0xFF8A6F4D),
                                                      ),
                                                      onPressed: () =>
                                                          _goToEditor(
                                                              log: log,
                                                              index: index),
                                                    ),
                                                  ),
                                                if (canDelete)
                                                  SizedBox(
                                                    height: 32,
                                                    width: 32,
                                                    child: IconButton(
                                                      padding: EdgeInsets.zero,
                                                      icon: const Icon(
                                                        Icons.delete,
                                                        size: 18,
                                                        color:
                                                            Color(0xFF9E5A5A),
                                                      ),
                                                      onPressed: () =>
                                                          _controller
                                                              .removeLog(index),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              backgroundColor: const Color(0xFF9E5A5A),
              foregroundColor: const Color(0xFFF3EBDD),
              onPressed: () => _goToEditor(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
