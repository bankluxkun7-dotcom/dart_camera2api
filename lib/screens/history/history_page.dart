import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/history_record.dart';
import '../../services/history_service.dart';
import '../scan/scan_result_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  late Future<List<HistoryRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = HistoryStore.load();
  }

  Future<void> _refresh() async {
    _future = HistoryStore.load();
    setState(() {});
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('ยืนยันการลบ',
            style: GoogleFonts.kanit(fontWeight: FontWeight.bold)),
        content: Text('คุณต้องการลบประวัติการสแกนทั้งหมดใช่หรือไม่?',
            style: GoogleFonts.kanit()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('ยกเลิก', style: GoogleFonts.kanit())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('ลบทั้งหมด',
                  style: GoogleFonts.kanit(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await HistoryStore.clear();
      if (mounted) {
        await _refresh();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ลบประวัติทั้งหมดแล้ว')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7938),
        elevation: 0,
        title: Text(
          'ประวัติการสแกน',
          style: GoogleFonts.kanit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'ลบทั้งหมด',
            onPressed: _clearAll,
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
          ),
        ],
      ),
      body: FutureBuilder<List<HistoryRecord>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)));
          }
          final data = snap.data!;
          if (data.isEmpty) {
            return _buildEmptyState();
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            color: const Color(0xFF10B981),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: data.length,
              itemBuilder: (context, i) {
                final rec = data[i];
                final timeText =
                    DateFormat('d MMM yyyy, HH:mm').format(rec.time);
                return _buildHistoryItem(rec, timeText);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Icon(
              Icons.history_rounded,
              size: 64,
              color: const Color(0xFF10B981).withOpacity(1),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ยังไม่มีประวัติการสแกน',
            style: GoogleFonts.kanit(
              color: const Color(0xFF6B7280),
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountCircle(int count) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.2),
            const Color(0xFF10B981).withOpacity(0.05)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$count',
          style: GoogleFonts.kanit(
            color: const Color(0xFF0F7938),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(HistoryRecord rec, String timeText) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 6,
                color: const Color(0xFF10B981),
              ),
              Expanded(
                child: InkWell(
                  onTap: () {
                    if (rec.items.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ScanResultPage(
                          imageFile: rec.imagePath != null
                              ? File(rec.imagePath!)
                              : null,
                          detectedName: rec.items.first,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        rec.imagePath != null
                            ? ClipOval(
                                child: Image.file(
                                  File(rec.imagePath!),
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _buildCountCircle(rec.items.length),
                                ),
                              )
                            : _buildCountCircle(rec.items.length),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.items.join(', '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.kanit(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: const Color(0xFF1F2937),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.access_time_rounded,
                                      size: 14, color: Color(0xFF9CA3AF)),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeText,
                                    style: GoogleFonts.kanit(
                                      fontSize: 12,
                                      color: const Color(0xFF6B7280),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                          color: Color(0xFFD1D5DB),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
