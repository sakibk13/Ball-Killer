import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/unintentional_provider.dart';
import '../models/unintentional_record.dart';
import '../utils/status_dialog.dart';
import 'loss_comparison_screen.dart';

class UnintentionalLossScreen extends StatefulWidget {
  const UnintentionalLossScreen({super.key});

  @override
  State<UnintentionalLossScreen> createState() => _UnintentionalLossScreenState();
}

class _UnintentionalLossScreenState extends State<UnintentionalLossScreen> with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  int _amount = 1;
  final _noteController = TextEditingController();
  late TabController _tabController;
  String _selectedMonthYear = 'Overall';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UnintentionalProvider>(context, listen: false).init();
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _saveRecord() async {
    if (_amount == 0) {
      StatusDialog.show(
        context,
        message: "Please specify a ball count greater or less than 0.",
        isSuccess: false,
        title: "INVALID COUNT",
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<UnintentionalProvider>(context, listen: false);

    final success = await provider.addRecord(
      lostCount: _amount,
      date: _selectedDate,
      recordedBy: auth.currentUser?.name ?? 'Admin',
      note: _noteController.text.trim(),
    );

    if (mounted) {
      if (success) {
        StatusDialog.show(
          context,
          message: "${_amount.abs()} unintentional ball(s) logged for ${DateFormat('dd MMM yyyy').format(_selectedDate)}.",
          isSuccess: true,
          title: "RECORD SAVED",
        );
        setState(() {
          _amount = 1;
          _noteController.clear();
        });
      } else {
        StatusDialog.show(
          context,
          message: "Failed to save record. Please check your connection.",
          isSuccess: false,
          title: "ERROR",
        );
      }
    }
  }

  void _showCustomNumberDialog() {
    final textCtrl = TextEditingController(text: _amount.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('ENTER BALL COUNT', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        content: TextField(
          controller: textCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontSize: 20),
          decoration: const InputDecoration(
            labelText: 'Number of Balls',
            labelStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            onPressed: () {
              final val = int.tryParse(textCtrl.text);
              if (val != null) {
                setState(() => _amount = val);
              }
              Navigator.pop(ctx);
            },
            child: const Text('SET', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unintProvider = Provider.of<UnintentionalProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final isAdmin = authProvider.isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('UNINTENTIONAL LOSS', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2, fontSize: 22)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_rounded, color: Colors.tealAccent),
            tooltip: 'Player vs Unintentional Comparison',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LossComparisonScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.purpleAccent,
          labelColor: Colors.purpleAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
          tabs: [
            if (isAdmin) const Tab(text: 'RECORD'),
            const Tab(text: 'HISTORY'),
            if (isAdmin) const Tab(text: 'MANAGE'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: () async {
              await unintProvider.refresh();
            },
            color: Colors.purpleAccent,
            child: TabBarView(
              controller: _tabController,
              children: [
                if (isAdmin) _buildRecordTab(unintProvider),
                _buildHistoryTab(unintProvider),
                if (isAdmin) _buildManageTab(unintProvider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // TAB 1: RECORD UNINTENTIONAL LOSS
  Widget _buildRecordTab(UnintentionalProvider provider) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('1. SELECT DATE', Colors.purpleAccent),
          const SizedBox(height: 12),
          _buildDateSelector(),
          const SizedBox(height: 25),
          _buildSectionHeader('2. TRACK BALL COUNT (INC / DEC)', Colors.purpleAccent),
          const SizedBox(height: 12),
          _buildCounterSection(),
          const SizedBox(height: 25),
          _buildSectionHeader('3. NOTE & DETAILS', Colors.purpleAccent),
          const SizedBox(height: 12),
          _buildNoteInput(),
          const SizedBox(height: 30),
          _buildSaveButton(provider.isLoading),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year && _selectedDate.month == now.month && _selectedDate.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = _selectedDate.year == yesterday.year && _selectedDate.month == yesterday.month && _selectedDate.day == yesterday.day;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.calendar_month_rounded, color: Colors.purpleAccent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('LOSS DATE', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 11, letterSpacing: 1)),
                          Text(
                            DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                            style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Icon(Icons.touch_app_rounded, color: Colors.purpleAccent, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickDateChip('TODAY', isToday, () {
                  setState(() => _selectedDate = DateTime.now());
                }),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildQuickDateChip('YESTERDAY', isYesterday, () {
                  setState(() => _selectedDate = DateTime.now().subtract(const Duration(days: 1)));
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDateChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? Colors.purpleAccent.withOpacity(0.25) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.purpleAccent : Colors.white10),
        ),
        child: Text(
          label,
          style: GoogleFonts.bebasNeue(
            color: isSelected ? Colors.purpleAccent : Colors.white54,
            fontSize: 12,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildCounterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Decrement Button
              InkWell(
                onTap: () => setState(() => _amount--),
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5),
                  ),
                  child: const Icon(Icons.remove_rounded, color: Colors.redAccent, size: 30),
                ),
              ),

              // Count Display (Tap to input directly)
              GestureDetector(
                onTap: _showCustomNumberDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.purpleAccent.withOpacity(0.2), Colors.deepPurpleAccent.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.purpleAccent.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$_amount',
                        style: GoogleFonts.bebasNeue(
                          color: _amount >= 0 ? Colors.purpleAccent : Colors.redAccent,
                          fontSize: 48,
                          height: 1,
                        ),
                      ),
                      Text(
                        'BALLS (TAP TO TYPE)',
                        style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 10, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),

              // Increment Button
              InkWell(
                onTap: () => setState(() => _amount++),
                borderRadius: BorderRadius.circular(25),
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.tealAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.tealAccent.withOpacity(0.5), width: 1.5),
                  ),
                  child: const Icon(Icons.add_rounded, color: Colors.tealAccent, size: 30),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Quick Increment / Decrement Pills
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickStepChip('+1', () => setState(() => _amount += 1)),
              _buildQuickStepChip('+2', () => setState(() => _amount += 2)),
              _buildQuickStepChip('+3', () => setState(() => _amount += 3)),
              _buildQuickStepChip('+5', () => setState(() => _amount += 5)),
              _buildQuickStepChip('-1', () => setState(() => _amount -= 1)),
              _buildQuickStepChip('RESET', () => setState(() => _amount = 1), isReset: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStepChip(String label, VoidCallback onTap, {bool isReset = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isReset ? Colors.white.withOpacity(0.08) : Colors.purpleAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isReset ? Colors.white24 : Colors.purpleAccent.withOpacity(0.3)),
        ),
        child: Text(
          label,
          style: GoogleFonts.bebasNeue(
            color: isReset ? Colors.white70 : Colors.purpleAccent,
            fontSize: 13,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildNoteInput() {
    return TextField(
      controller: _noteController,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'e.g. Lost in bushes / ground crack / practice loss',
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
        labelText: 'Reason / Note (Optional)',
        labelStyle: const TextStyle(color: Colors.purpleAccent),
        prefixIcon: const Icon(Icons.edit_note_rounded, color: Colors.purpleAccent, size: 22),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildSaveButton(bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purpleAccent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
        ),
        onPressed: isLoading ? null : _saveRecord,
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('SAVE UNINTENTIONAL RECORD', style: GoogleFonts.bebasNeue(fontSize: 17, color: Colors.white, letterSpacing: 1.2)),
                ],
              ),
      ),
    );
  }

  // TAB 2: HISTORY
  Widget _buildHistoryTab(UnintentionalProvider provider) {
    final availableMonths = provider.getAvailableMonths();
    final filteredRecords = provider.getRecordsForMonth(_selectedMonthYear);
    final totalCount = provider.getTotalLostForMonth(_selectedMonthYear);

    // Group records by Month string, then by Date string
    final Map<String, Map<String, List<UnintentionalRecord>>> grouped = {};
    final sorted = List<UnintentionalRecord>.from(filteredRecords)..sort((a, b) => b.date.compareTo(a.date));

    for (var r in sorted) {
      final monthKey = DateFormat('MMMM yyyy').format(r.date).toUpperCase();
      final dateKey = DateFormat('yyyy-MM-dd').format(r.date);
      grouped.putIfAbsent(monthKey, () => {});
      grouped[monthKey]!.putIfAbsent(dateKey, () => []);
      grouped[monthKey]![dateKey]!.add(r);
    }

    final monthKeys = grouped.keys.toList();

    return Column(
      children: [
        _buildMonthPicker(availableMonths),
        _buildStatsHeader(totalCount),
        Expanded(
          child: monthKeys.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.history_toggle_off_rounded, size: 70, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text('NO UNINTENTIONAL LOSS RECORDS', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 18, letterSpacing: 1.2)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: monthKeys.length,
                  itemBuilder: (context, mIndex) {
                    final monthStr = monthKeys[mIndex];
                    final dailyData = grouped[monthStr]!;
                    final dateKeys = dailyData.keys.toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 16, bottom: 12),
                          child: Row(
                            children: [
                              Container(width: 4, height: 18, color: Colors.purpleAccent),
                              const SizedBox(width: 10),
                              Text(monthStr, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20, letterSpacing: 1.5)),
                            ],
                          ),
                        ),
                        ...dateKeys.map((dateStr) {
                          final dayRecords = dailyData[dateStr]!;
                          final date = DateTime.parse(dateStr);
                          final dailyTotal = dayRecords.fold(0, (sum, r) => sum + r.lostCount);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF020C3B),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: Colors.white.withOpacity(0.08)),
                            ),
                            child: Column(
                              children: [
                                // Date Header with DAILY SUBTOTAL
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.calendar_today_rounded, color: Colors.purpleAccent, size: 14),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat('EEEE, dd MMMM').format(date).toUpperCase(),
                                            style: GoogleFonts.bebasNeue(color: Colors.purpleAccent, fontSize: 14, letterSpacing: 1),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.purpleAccent.withOpacity(0.18),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          'DATE SUBTOTAL: $dailyTotal',
                                          style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 13, letterSpacing: 0.8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Daily Entries
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: dayRecords.length,
                                  separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                                  itemBuilder: (context, i) {
                                    final r = dayRecords[i];
                                    return ListTile(
                                      dense: true,
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor: Colors.purpleAccent.withOpacity(0.15),
                                        child: Text(
                                          '${r.lostCount > 0 ? "+" : ""}${r.lostCount}',
                                          style: GoogleFonts.bebasNeue(color: Colors.purpleAccent, fontSize: 14),
                                        ),
                                      ),
                                      title: Text(
                                        r.note.isNotEmpty ? r.note : 'Unintentional Ground Loss',
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                      subtitle: Text(
                                        'By ${r.recordedBy} • ${DateFormat('hh:mm a').format(r.date)}',
                                        style: const TextStyle(color: Colors.white38, fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 3: MANAGE (EDIT / DELETE)
  Widget _buildManageTab(UnintentionalProvider provider) {
    final records = provider.records;
    if (records.isEmpty) {
      return Center(
        child: Text('No records found to manage', style: GoogleFonts.poppins(color: Colors.white24)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: records.length,
      itemBuilder: (context, i) => _buildManageCard(records[i], provider),
    );
  }

  Widget _buildManageCard(UnintentionalRecord r, UnintentionalProvider provider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Colors.purpleAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              '${r.lostCount > 0 ? "+" : ""}${r.lostCount}',
              style: GoogleFonts.bebasNeue(color: Colors.purpleAccent, fontSize: 18),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.note.isNotEmpty ? r.note : 'Unintentional Loss',
                  style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 16, letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  DateFormat('dd MMM yyyy, hh:mm a').format(r.date),
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                Text(
                  'Recorded by: ${r.recordedBy}',
                  style: const TextStyle(color: Colors.white30, fontSize: 10),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                onPressed: () => _showEditDialog(r, provider),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _showDeleteConfirm(r, provider),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditDialog(UnintentionalRecord r, UnintentionalProvider provider) {
    final countCtrl = TextEditingController(text: r.lostCount.toString());
    final noteCtrl = TextEditingController(text: r.note);
    DateTime editDate = r.date;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF020C3B),
          title: Text('EDIT UNINTENTIONAL RECORD', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: editDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setModalState(() => editDate = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(DateFormat('dd MMM yyyy').format(editDate), style: const TextStyle(color: Colors.white)),
                        const Icon(Icons.calendar_today, color: Colors.purpleAccent, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: countCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'BALL COUNT',
                    labelStyle: TextStyle(color: Colors.purpleAccent),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'NOTE',
                    labelStyle: TextStyle(color: Colors.white38),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.purpleAccent)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              onPressed: () {
                final newCount = int.tryParse(countCtrl.text);
                if (newCount != null) {
                  final updated = UnintentionalRecord(
                    id: r.id,
                    lostCount: newCount,
                    date: editDate,
                    monthYear: DateFormat('MMMM yyyy').format(editDate),
                    recordedBy: r.recordedBy,
                    note: noteCtrl.text.trim(),
                    createdAt: r.createdAt,
                  );
                  final admin = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';
                  provider.updateRecord(updated, r.lostCount, admin);
                  Navigator.pop(ctx);
                }
              },
              child: const Text('UPDATE', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirm(UnintentionalRecord r, UnintentionalProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE RECORD', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
        content: Text(
          'Delete unintentional loss record of ${r.lostCount} ball(s) on ${DateFormat('dd MMM yyyy').format(r.date)}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              final admin = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';
              provider.deleteRecord(r.id!, r.lostCount, admin);
              Navigator.pop(ctx);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthPicker(List<String> months) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF020C3B),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: months.length,
        itemBuilder: (context, index) {
          final m = months[index];
          final isSelected = _selectedMonthYear == m;
          final display = m == 'Overall' ? 'OVERALL' : m.toUpperCase();
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthYear = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [Colors.purpleAccent, Colors.deepPurple])
                    : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? Colors.purpleAccent : Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(
                display,
                style: GoogleFonts.bebasNeue(
                  color: isSelected ? Colors.white : Colors.white38,
                  fontSize: 14,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatsHeader(int total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF020C3B),
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.help_outline_rounded, color: Colors.purpleAccent, size: 16),
              const SizedBox(width: 8),
              Text(
                'TOTAL UNINTENTIONAL BALLS',
                style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 13, letterSpacing: 1.2),
              ),
            ],
          ),
          Text(
            '$total',
            style: GoogleFonts.bebasNeue(color: Colors.purpleAccent, fontSize: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: color),
        const SizedBox(width: 10),
        Text(title, style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 17, letterSpacing: 1)),
      ],
    );
  }
}
