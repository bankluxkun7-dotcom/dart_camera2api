import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/med_item.dart';
import '../../repositories/med_repository.dart';
import 'widgets/medicine_detail_sheet.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final repo = MedRepository();
  final _search = TextEditingController();
  List<MedItem> _all = [];
  bool _loading = true;
  String _quick = 'ทั้งหมด';

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await repo.loadAll();
      if (!mounted) return;
      setState(() {
        _all = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลด meds.xlsm ไม่สำเร็จ: $e')),
      );
    }
  }

  List<MedItem> get _filtered {
    final q = _search.text.trim().toLowerCase();
    var base = _all.where((m) {
      final t = '${m.name} ${m.description}'.toLowerCase();
      return q.isEmpty || t.contains(q);
    }).toList();

    if (_quick == 'ทั้งหมด') return base;
    if (_quick == 'ความดันโลหิต') {
      base = base.where((m) {
        final t = '${m.name} ${m.description}'.toLowerCase();
        return t.contains('ความดัน') ||
            t.contains('ความดันโลหิต') ||
            t.contains('hypertension');
      }).toList();
    }
    return base;
  }

  void _openDetail(MedItem m) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MedDetailSheet(item: m),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F7938),
        elevation: 0,
        title: Text(
          'ยาความดันโลหิต',
          style: GoogleFonts.kanit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.local_pharmacy_rounded, color: Colors.white),
          onPressed: () {},
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xFF10B981),
                  ),
                  hintText: 'ค้นหายา...',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE5E7EB),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF10B981),
                      width: 2,
                    ),
                  ),
                  hintStyle: GoogleFonts.kanit(
                    color: const Color(0xFF9CA3AF),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  FilterChip(
                    label: Text(
                      'ทั้งหมด',
                      style: GoogleFonts.kanit(
                        fontWeight: _quick == 'ทั้งหมด'
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    selected: _quick == 'ทั้งหมด',
                    onSelected: (_) => setState(() => _quick = 'ทั้งหมด'),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF10B981).withOpacity(0.2),
                    side: BorderSide(
                      color: _quick == 'ทั้งหมด'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(
                      'ความดันโลหิต',
                      style: GoogleFonts.kanit(
                        fontWeight: _quick == 'ความดันโลหิต'
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                    selected: _quick == 'ความดันโลหิต',
                    onSelected: (_) =>
                        setState(() => _quick = 'ความดันโลหิต'),
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF10B981).withOpacity(0.2),
                    side: BorderSide(
                      color: _quick == 'ความดันโลหิต'
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _load,
                    tooltip: 'รีเฟรช',
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ],
              ),
            ),
            if (_loading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_pharmacy_rounded,
                        size: 64,
                        color: const Color(0xFF10B981).withOpacity(0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ไม่พบรายการ',
                        style: GoogleFonts.kanit(
                          color: cs.onSurfaceVariant,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
            Expanded(
              child: Container(
                color: const Color.fromARGB(255, 229, 234, 233), 
                child: GridView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (_, i) {
                    final m = _filtered[i];
                    return GestureDetector(
                      onTap: () => _openDetail(m),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              offset: const Offset(0, 8),
                              blurRadius: 12,
                              spreadRadius: -1,
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF8FAFC), 
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
                                ),
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                                    child: Image.asset(
                                      m.imagePath,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.eco_outlined, color: Color(0xFF10B981), size: 32),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 4,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      m.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.kanit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: const Color(0xFF1F2937),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      m.description.isEmpty ? 'ไม่มีสรรพคุณ' : m.description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.kanit(
                                        color: const Color(0xFF4B5563),
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        const Icon(Icons.info_rounded, size: 14, color: Color(0xFF10B981)),
                                        const SizedBox(width: 4),
                                        Text(
                                          "ดูข้อมูล",
                                          style: GoogleFonts.kanit(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF10B981),
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
            )
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }
}
