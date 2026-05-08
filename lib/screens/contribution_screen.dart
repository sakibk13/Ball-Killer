import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/contribution_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/ball_provider.dart';
import '../providers/fine_provider.dart';
import '../models/contribution.dart';
import '../models/fine_payment.dart';
import '../utils/status_dialog.dart';
import '../utils/export_service.dart';
import '../utils/string_utils.dart';
import '../utils/date_utils.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _takaController = TextEditingController();
  final _ballCountController = TextEditingController(text: '0');
  final _tapeCountController = TextEditingController(text: '0');
  final _infoController = TextEditingController();
  final _searchController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _selectedMonthYear = 'Overall';
  late List<String> _monthList;
  bool _isFinePayment = false;
  bool _isOther = false;
  String? _pickedImageBase64;

  @override
  void initState() {
    super.initState();
    _generateMonthList();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ContributionProvider>(context, listen: false).fetchContributions();
      Provider.of<FineProvider>(context, listen: false).fetchPayments();
      Provider.of<BallProvider>(context, listen: false).fetchPlayers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _generateMonthList() {
    _monthList = ['Overall'];
    final provider = Provider.of<ContributionProvider>(context, listen: false);
    final fineProvider = Provider.of<FineProvider>(context, listen: false);
    
    Set<String> months = {};
    for (var c in provider.contributions) {
      if (c.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(c.monthYear));
      }
    }
    for (var p in fineProvider.payments) {
      if (p.monthYear.isNotEmpty) {
        months.add(DateUtilsHelper.normalizeMonthYear(p.monthYear));
      }
    }
    
    months.add(DateFormat('MMMM yyyy').format(DateTime.now()));
    
    // Always include the previous month (April 2026 if now is May 2026)
    DateTime prevMonth = DateTime(DateTime.now().year, DateTime.now().month - 1, 1);
    months.add(DateFormat('MMMM yyyy').format(prevMonth));
    
    List<String> sortedMonths = months.toList();
    sortedMonths.sort((a, b) {
      try {
        DateTime da = DateFormat('MMMM yyyy').parse(a);
        DateTime db = DateFormat('MMMM yyyy').parse(b);
        return db.compareTo(da);
      } catch (_) {
        return b.compareTo(a);
      }
    });
    
    _monthList.addAll(sortedMonths);
  }

  void _updateTotal() {
    int balls = int.tryParse(_ballCountController.text) ?? 0;
    int tapes = int.tryParse(_tapeCountController.text) ?? 0;
    int total = (balls * 40) + (tapes * 20);
    if (total > 0) _takaController.text = total.toString();
  }

  void _showAddSheet({Contribution? editItem}) {
    final players = Provider.of<BallProvider>(context, listen: false).players;
    
    if (editItem != null) {
      _selectedDate = editItem.date;
      _nameController.text = editItem.name;
      _takaController.text = editItem.taka.toInt().toString();
      _ballCountController.text = editItem.ballCount.toString();
      _tapeCountController.text = editItem.tapeCount.toString();
      _infoController.text = editItem.ballTape;
      _isFinePayment = editItem.isFinePayment;
      _isOther = editItem.isOther;
      _pickedImageBase64 = editItem.photoUrl;
    } else {
      _selectedDate = DateTime.now(); 
      _nameController.clear();
      _takaController.clear();
      _ballCountController.text = '0';
      _tapeCountController.text = '0';
      _infoController.clear();
      _isFinePayment = false;
      _isOther = false;
      _pickedImageBase64 = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          decoration: const BoxDecoration(color: Color(0xFF020C3B), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(10))),
                const SizedBox(height: 20),
                Text(editItem == null ? 'ADD RECORD' : 'UPDATE RECORD', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, letterSpacing: 1.5)),
                const SizedBox(height: 25),
                
                if (_isOther) ...[
                  GestureDetector(
                    onTap: () async {
                      final ImagePicker picker = ImagePicker();
                      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                      if (image != null) {
                        final bytes = await image.readAsBytes();
                        setModalState(() {
                          _pickedImageBase64 = base64Encode(bytes);
                        });
                      }
                    },
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: _pickedImageBase64 != null 
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Image.memory(base64Decode(_pickedImageBase64!), fit: BoxFit.cover),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_outlined, color: Colors.tealAccent, size: 30),
                              const SizedBox(height: 8),
                              Text('Add Item Photo', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                            ],
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                GestureDetector(
                  onTap: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2101),
                    );
                    if (picked != null) setModalState(() => _selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Record Date', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            Text(DateFormat('dd MMMM, yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Icon(Icons.calendar_today, color: Colors.tealAccent, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _nameController.text),
                  optionsBuilder: (v) => players.where((p) => p.name.toLowerCase().contains(v.text.toLowerCase())).map((p) => p.name),
                  onSelected: (v) => _nameController.text = v,
                  fieldViewBuilder: (ctx, focusCtrl, focus, onSub) => TextField(
                    controller: focusCtrl,
                    focusNode: focus,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('Person Name', Icons.person_outline),
                    onChanged: (v) => _nameController.text = v,
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("OTHER ITEM?", style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 14)),
                            Switch(
                              value: _isOther,
                              onChanged: (val) => setModalState(() => _isOther = val),
                              activeThumbColor: Colors.tealAccent,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!_isOther) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text("FOR FINE?", style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 14)),
                              Switch(
                                value: _isFinePayment,
                                onChanged: (val) => setModalState(() => _isFinePayment = val),
                                activeThumbColor: Colors.tealAccent,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                if (!_isOther) ...[
                  Row(
                    children: [
                      Expanded(child: _buildCounter('BALLS (40৳)', _ballCountController, () => setModalState(() => _updateTotal()))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildCounter('TAPES (20৳)', _tapeCountController, () => setModalState(() => _updateTotal()))),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],

                TextField(
                  controller: _takaController, 
                  keyboardType: TextInputType.number, 
                  style: GoogleFonts.bebasNeue(color: Color(0xFF00E676), fontSize: 24), 
                  decoration: _inputDeco(_isOther ? 'Est. Value (৳) (Optional)' : 'Total Amount (৳)', Icons.payments_outlined),
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: _infoController, 
                  style: const TextStyle(color: Colors.white70, fontSize: 14), 
                  decoration: _inputDeco(_isOther ? 'Item Name (e.g. Bat, Mat)' : 'Optional Note', Icons.note_alt_outlined),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_nameController.text.isEmpty) return;
                      
                      int balls = _isOther ? 0 : (int.tryParse(_ballCountController.text) ?? 0);
                      int tapes = _isOther ? 0 : (int.tryParse(_tapeCountController.text) ?? 0);
                      
                      String finalNote = _infoController.text.trim();
                      if (!_isOther) {
                        List<String> items = [];
                        if (balls > 0) items.add('$balls ball${balls > 1 ? "s" : ""}');
                        if (tapes > 0) items.add('$tapes tape${tapes > 1 ? "s" : ""}');
                        String autoNote = items.join(", ");
                        if (autoNote.isNotEmpty && !finalNote.contains(autoNote)) {
                           if (editItem == null) {
                              finalNote = autoNote;
                              if (_infoController.text.isNotEmpty) finalNote = "$autoNote | ${_infoController.text}";
                           }
                        }
                      }

                      String? selectedPlayerId;
                      try {
                        selectedPlayerId = players.firstWhere((p) => p.name == _nameController.text).id;
                      } catch (_) {}

                      final c = Contribution(
                        id: editItem?.id,
                        playerId: selectedPlayerId,
                        name: _nameController.text,
                        taka: double.tryParse(_takaController.text) ?? 0,
                        date: _selectedDate,
                        monthYear: DateFormat('MMMM yyyy').format(_selectedDate),
                        ballTape: finalNote,
                        ballCount: balls,
                        tapeCount: tapes,
                        isFinePayment: !_isOther, // Automatically true for cash
                        isOther: _isOther,
                        photoUrl: _pickedImageBase64,
                      );
                      
                      final provider = Provider.of<ContributionProvider>(context, listen: false);
                      final success = editItem == null 
                          ? await provider.addContribution(c)
                          : await provider.updateContribution(c);

                      if (mounted) {
                        Navigator.pop(context);
                        StatusDialog.show(
                          context, 
                          message: success ? (editItem == null ? "Record saved." : "Record updated.") : "Action failed.", 
                          isSuccess: success, 
                          title: success ? "SUCCESS" : "FAILED",
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      elevation: 8,
                    ),
                    child: Text(editItem == null ? 'SAVE RECORD' : 'UPDATE RECORD', style: GoogleFonts.bebasNeue(fontSize: 20, letterSpacing: 1.2, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounter(String label, TextEditingController ctrl, VoidCallback onUpdate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white24, size: 20), onPressed: () {
                int v = int.tryParse(ctrl.text) ?? 0;
                if (v > 0) ctrl.text = (v - 1).toString();
                onUpdate();
              }),
              Text(ctrl.text, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.tealAccent, size: 20), onPressed: () {
                int v = int.tryParse(ctrl.text) ?? 0;
                ctrl.text = (v + 1).toString();
                onUpdate();
              }),
            ],
          ),
        )
      ],
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      prefixIcon: Icon(icon, color: Colors.tealAccent, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.tealAccent, width: 1)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ContributionProvider>(context);
    final fineProvider = Provider.of<FineProvider>(context);
    final ballProvider = Provider.of<BallProvider>(context);
    final isAdmin = Provider.of<AuthProvider>(context).isAdmin;

    return Scaffold(
      backgroundColor: const Color(0xFF051970),
      appBar: AppBar(
        title: Text('FINANCIAL RECORDS', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 24, letterSpacing: 1.5)),
        backgroundColor: const Color(0xFF020C3B),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.tealAccent),
            onPressed: () async {
              try {
                if (_tabController.index == 0) {
                  final summaryData = _getUnifiedSummary(provider, fineProvider);
                  await ExportService.exportFinancialSummaryReport(
                    monthYear: _selectedMonthYear, 
                    data: summaryData,
                    players: ballProvider.players,
                  );
                } else if (_tabController.index == 2) {
                  final otherContributions = provider.contributions
                      .where((c) => c.isOther && (_selectedMonthYear == 'Overall' || c.monthYear == _selectedMonthYear))
                      .toList();
                  await ExportService.exportOtherContributionsReport(
                    monthYear: _selectedMonthYear,
                    contributions: otherContributions,
                    players: ballProvider.players,
                  );
                } else {
                  final detailedData = _getUnifiedDetailedList(provider, fineProvider);
                  await ExportService.exportFinancialDetailedReport(
                    monthYear: _selectedMonthYear, 
                    contributions: detailedData,
                    players: ballProvider.players,
                  );
                }
                if (mounted) {
                  StatusDialog.show(context, title: "SUCCESS", message: "Financial PDF Generated!", isSuccess: true);
                }
              } catch (e) {
                if (mounted) {
                  StatusDialog.show(context, title: "ERROR", message: "Failed: $e", isSuccess: false);
                }
              }
            },
          ),
          const SizedBox(width: 10),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.tealAccent,
          labelColor: Colors.tealAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
          tabs: [
            const Tab(text: 'SUMMARY'),
            const Tab(text: 'DETAILED'),
            const Tab(text: 'OTHER'),
            if (isAdmin) const Tab(text: 'MANAGE'),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: RefreshIndicator(
            onRefresh: () async {
              await provider.fetchContributions(force: true);
              await fineProvider.fetchPayments();
            },
            color: Colors.tealAccent,
            child: Column(
              children: [
                _buildMonthPickerWithSearch(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUnifiedSummary(provider, fineProvider),
                      _buildUnifiedDetailedCalendar(provider, fineProvider, ballProvider),
                      _buildOtherContributionsTab(provider, ballProvider),
                      if (isAdmin) _buildManageTab(provider),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: isAdmin ? FloatingActionButton(
        onPressed: () => _showAddSheet(), 
        backgroundColor: Colors.tealAccent, 
        child: const Icon(Icons.add_card, color: Colors.white)
      ) : null,
    );
  }

  Widget _buildMonthPickerWithSearch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(color: Color(0xFF020C3B)),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _monthList.map((m) {
                bool isSel = _selectedMonthYear == m;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMonthYear = m),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSel ? Colors.tealAccent : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(m, style: GoogleFonts.bebasNeue(color: isSel ? Colors.white : Colors.white38, fontSize: 14)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search Name, Date, Amount, Note...',
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: const Icon(Icons.search, color: Colors.tealAccent, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, Map<String, double>> _getUnifiedSummary(ContributionProvider cp, FineProvider fp) {
    Map<String, Map<String, double>> unified = {};

    // 1. Process all cash contributions
    for (var c in cp.contributions) {
      if (c.isOther) continue; // Skip items like balls/tape
      String month = DateUtilsHelper.normalizeMonthYear(c.monthYear);
      String name = StringUtils.capitalize(c.name);
      
      unified.putIfAbsent(month, () => {});
      unified[month]![name] = (unified[month]![name] ?? 0) + c.taka;
    }

    // 2. Process all fine payments
    for (var f in fp.payments) {
      String month = DateUtilsHelper.normalizeMonthYear(f.monthYear);
      String name = StringUtils.capitalize(f.playerName);
      
      unified.putIfAbsent(month, () => {});
      unified[month]![name] = (unified[month]![name] ?? 0) + f.amountPaid;
    }

    // Filter by selected month if not 'Overall'
    if (_selectedMonthYear != 'Overall') {
      String searchM = DateUtilsHelper.normalizeMonthYear(_selectedMonthYear);
      return unified.containsKey(searchM) ? { searchM: unified[searchM]! } : {};
    }

    return unified;
  }
  List<dynamic> _getUnifiedDetailedList(ContributionProvider p, FineProvider fp) {
    final search = _searchController.text.toLowerCase();
    String searchM = DateUtilsHelper.normalizeMonthYear(_selectedMonthYear);

    final list = (searchM == 'Overall'
        ? p.contributions
        : p.contributions.where((c) => DateUtilsHelper.normalizeMonthYear(c.monthYear) == searchM).toList());

    final payments = (searchM == 'Overall'
        ? fp.payments
        : fp.payments.where((pay) => DateUtilsHelper.normalizeMonthYear(pay.monthYear) == searchM).toList());

    List<dynamic> combined = [...list, ...payments];
    
    if (search.isNotEmpty) {
      combined = combined.where((item) {
        bool isFine = item is FinePayment;
        String name = isFine ? item.playerName : item.name;
        String note = isFine ? (item.note ?? "Fine Payment") : item.ballTape;
        String amount = (isFine ? item.amountPaid : item.taka).toInt().toString();
        String date = DateFormat('dd MMM yyyy').format(item.date);
        
        return name.toLowerCase().contains(search) || 
               note.toLowerCase().contains(search) || 
               amount.contains(search) || 
               date.toLowerCase().contains(search);
      }).toList();
    }

    combined.sort((a, b) => b.date.compareTo(a.date));
    return combined;
  }

  Widget _buildUnifiedSummary(ContributionProvider p, FineProvider fp) {
    final data = _getUnifiedSummary(p, fp);

    if (data.isEmpty) return const Center(child: Text('No records found for this period', style: TextStyle(color: Colors.white24)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: data.length,
      itemBuilder: (ctx, i) {
        String monthKey = data.keys.elementAt(i);
        Map<String, double> players = data[monthKey]!;
        double total = players.values.fold(0, (s, v) => s + v);
        
        String monthName = monthKey;
        try {
          DateTime date = DateFormat('MMMM yyyy').parse(monthKey);
          monthName = DateFormat('MMMM yyyy').format(date);
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: const Color(0xFF020C3B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, 5))],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(monthName.toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 22, letterSpacing: 1)),
                        Text('TOTAL COLLECTION', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(color: Color(0xFF00E676).withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text('${total.toStringAsFixed(0)} ৳', style: GoogleFonts.bebasNeue(color: Color(0xFF00E676), fontSize: 24)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: players.entries.map((e) {
                    final contribs = p.contributions.where((c) => c.name == e.key && c.monthYear == monthKey && !c.isOther).toList();
                    final fines = fp.payments.where((pay) => pay.playerName == e.key && pay.monthYear == monthKey).toList();
                    
                    String status = "";
                    if (contribs.isNotEmpty) status += "Contrib: ${contribs.length} ";
                    if (fines.isNotEmpty) status += "Fine: ${fines.length}";

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(width: 4, height: 25, decoration: BoxDecoration(color: Colors.tealAccent.withOpacity(0.5), borderRadius: BorderRadius.circular(2))),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(StringUtils.capitalize(e.key), style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                                      if (!Provider.of<AuthProvider>(context, listen: false).isGuest)
                                        Text(status, style: const TextStyle(color: Colors.white24, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text('${e.value.toStringAsFixed(0)} ৳', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 20)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUnifiedDetailedCalendar(ContributionProvider p, FineProvider fp, BallProvider bp) {
    final combined = _getUnifiedDetailedList(p, fp);
    final isGuest = Provider.of<AuthProvider>(context, listen: false).isGuest;
    
    if (combined.isEmpty) return const Center(child: Text('No transactions found', style: TextStyle(color: Colors.white24)));

    // Group by Date
    Map<String, List<dynamic>> grouped = {};
    for (var item in combined) {
      String dateStr = DateFormat('yyyy-MM-dd').format(item.date);
      grouped.putIfAbsent(dateStr, () => []);
      grouped[dateStr]!.add(item);
    }

    var dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: dates.length,
      itemBuilder: (context, index) {
        String dateKey = dates[index];
        DateTime date = DateTime.parse(dateKey);
        List<dynamic> items = grouped[dateKey]!;

        return Container(
          margin: const EdgeInsets.only(bottom: 25),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date Card
              Container(
                width: 65,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF020C3B), Color(0xFF051970)]),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Text(DateFormat('MMM').format(date).toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14)),
                    Text(DateFormat('dd').format(date), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 28, height: 1)),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              // Items List
              Expanded(
                child: Column(
                  children: items.map((item) {
                    bool isFine = item is FinePayment;
                    bool isDeductibleContrib = item is Contribution && item.isFinePayment;
                    
                    String name = isFine ? item.playerName : item.name;
                    String? playerId = isFine ? item.playerId : item.playerId;
                    
                    dynamic player;
                    if (playerId != null) {
                      try {
                        player = bp.players.firstWhere((p) => p.id == playerId);
                      } catch (_) {}
                    }

                    String note = isFine 
                        ? "Fine Collection${item.note != null && item.note!.isNotEmpty ? " | ${item.note!}" : ""}" 
                        : (isDeductibleContrib ? "(Fine) " : "") + item.ballTape;
                    double amount = isFine ? item.amountPaid : item.taka;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: isFine || isDeductibleContrib ? Color(0xFF00E676).withOpacity(0.2) : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.white10,
                            backgroundImage: (player != null && player.photoUrl.isNotEmpty) ? MemoryImage(base64Decode(player.photoUrl)) : null,
                            child: (player == null || player.photoUrl.isEmpty) ? Text(name[0].toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.tealAccent)) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(StringUtils.capitalize(name), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                if (!isGuest)
                                  Text(note, style: TextStyle(color: isFine || isDeductibleContrib ? Color(0xFF00E676).withOpacity(0.5) : Colors.white38, fontSize: 9)),
                              ],
                            ),
                          ),
                          Text('${amount.toInt()} ৳', style: GoogleFonts.bebasNeue(color: isFine || isDeductibleContrib ? Color(0xFF00E676) : Colors.white70, fontSize: 18)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtherContributionsTab(ContributionProvider p, BallProvider bp) {
    final search = _searchController.text.toLowerCase();
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;
    final list = p.contributions.where((c) => c.isOther && (_selectedMonthYear == 'Overall' || c.monthYear == _selectedMonthYear)).toList();
    
    var filtered = list;
    if (search.isNotEmpty) {
      filtered = list.where((c) {
        String date = DateFormat('dd MMM yyyy').format(c.date);
        return c.name.toLowerCase().contains(search) || 
               c.ballTape.toLowerCase().contains(search) || 
               c.taka.toInt().toString().contains(search) || 
               date.toLowerCase().contains(search);
      }).toList();
    }
    
    if (filtered.isEmpty) return const Center(child: Text('No other contributions found', style: TextStyle(color: Colors.white24)));

    final double totalEstValue = filtered.fold(0, (sum, item) => sum + item.taka);
    final int totalBalls = filtered.fold(0, (sum, item) => sum + item.ballCount);
    final int totalTapes = filtered.fold(0, (sum, item) => sum + item.tapeCount);

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.tealAccent.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.tealAccent.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('OTHER CONTRIBUTIONS SUB-TOTAL', style: GoogleFonts.bebasNeue(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Color(0xFF00E676).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text('${totalEstValue.toInt()} ৳', style: GoogleFonts.bebasNeue(color: Color(0xFF00E676), fontSize: 20)),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMiniStat('TOTAL ITEMS', '${filtered.length}', Colors.blueAccent),
                  _buildMiniStat('TOTAL BALLS', '$totalBalls', Colors.tealAccent),
                  _buildMiniStat('TOTAL TAPES', '$totalTapes', Colors.purpleAccent),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              final item = filtered[i];
              dynamic player;
              try {
                 player = bp.players.firstWhere((pl) => pl.id == item.playerId);
              } catch(_) {}
              
              return Container(
                margin: const EdgeInsets.only(bottom: 15),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF020C3B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                     CircleAvatar(
                      radius: 25,
                      backgroundColor: Colors.white10,
                      backgroundImage: (item.photoUrl != null && item.photoUrl!.isNotEmpty) 
                          ? MemoryImage(base64Decode(item.photoUrl!)) 
                          : (player != null && player.photoUrl.isNotEmpty) 
                              ? MemoryImage(base64Decode(player.photoUrl)) 
                              : null,
                      child: (item.photoUrl == null || item.photoUrl!.isEmpty) && (player == null || player.photoUrl.isEmpty)
                          ? Text(item.name[0].toUpperCase(), style: const TextStyle(color: Colors.tealAccent, fontSize: 20))
                          : null,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(StringUtils.capitalize(item.name), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(item.ballTape, style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          Text(DateFormat('dd MMM yyyy').format(item.date), style: const TextStyle(color: Colors.tealAccent, fontSize: 10)),
                        ],
                      ),
                    ),
                    if (item.taka > 0)
                      Text('${item.taka.toInt()} ৳', style: GoogleFonts.bebasNeue(color: Color(0xFF00E676), fontSize: 20)),
                    
                    if (isAdmin) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showAddSheet(editItem: item),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _showDeleteConfirm(item.id!, p),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.bebasNeue(color: color, fontSize: 18)),
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 10, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildMonthPicker() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: const Color(0xFF020C3B),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        itemCount: _monthList.length,
        itemBuilder: (context, index) {
          final m = _monthList[index];
          final isSelected = _selectedMonthYear == m;
          String display = m == 'Overall' ? 'OVERALL' : m.toUpperCase();
          return GestureDetector(
            onTap: () => setState(() => _selectedMonthYear = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: isSelected ? const LinearGradient(colors: [Colors.tealAccent, Colors.blueAccent]) : null,
                color: isSelected ? null : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isSelected ? Colors.tealAccent : Colors.white10),
              ),
              alignment: Alignment.center,
              child: Text(display, style: GoogleFonts.bebasNeue(color: isSelected ? Colors.white : Colors.white38, fontSize: 14)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildManageTab(ContributionProvider p) {
    final list = _selectedMonthYear == 'Overall' 
        ? p.contributions 
        : p.contributions.where((c) => c.monthYear == _selectedMonthYear).toList();
    
    if (list.isEmpty) return const Center(child: Text('No records found', style: TextStyle(color: Colors.white24)));
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (ctx, i) {
        final item = list[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05), 
            borderRadius: BorderRadius.circular(20), 
            border: Border.all(color: Colors.white10)
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text('${DateFormat('dd MMM yyyy').format(item.date)} | ${item.taka.toStringAsFixed(0)}৳', style: const TextStyle(color: Colors.tealAccent, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 20),
                onPressed: () => _showAddSheet(editItem: item),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                onPressed: () => _showDeleteConfirm(item.id!, p),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirm(String id, ContributionProvider p) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('DELETE CONTRIBUTION?', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1)),
        content: const Text('Are you sure you want to remove this transaction record?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              p.deleteContribution(id);
              Navigator.pop(context);
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
