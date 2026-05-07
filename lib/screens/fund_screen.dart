import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/ball_provider.dart';
import '../providers/fund_provider.dart';
import '../providers/auth_provider.dart';
import '../models/fund.dart';
import '../utils/date_utils.dart';
import '../utils/export_service.dart';
import '../utils/status_dialog.dart';

class FundScreen extends StatefulWidget {
  const FundScreen({super.key});

  @override
  State<FundScreen> createState() => _FundScreenState();
}

class _FundScreenState extends State<FundScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<FundProvider>(context, listen: false).fetchFunds();
    });
  }

  @override
  Widget build(BuildContext context) {
    final fundProvider = Provider.of<FundProvider>(context);
    final ballProvider = Provider.of<BallProvider>(context);
    final isAdmin = Provider.of<AuthProvider>(context, listen: false).isAdmin;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFF051970),
        appBar: AppBar(
          title: Text('Club Fund', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
          backgroundColor: const Color(0xFF020C3B),
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.tealAccent),
              onPressed: () async {
                try {
                  await ExportService.exportFundReport(
                    funds: fundProvider.funds,
                    grandTotal: fundProvider.grandTotal,
                    players: ballProvider.players,
                  );
                  if (mounted) {
                    StatusDialog.show(context, title: "SUCCESS", message: "Fund Report Generated!", isSuccess: true);
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
            indicatorColor: Colors.tealAccent,
            labelColor: Colors.tealAccent,
            unselectedLabelColor: Colors.white38,
            labelStyle: GoogleFonts.bebasNeue(fontSize: 14, letterSpacing: 1),
            tabs: const [
              Tab(text: 'OVERALL'),
              Tab(text: 'INCOME'),
              Tab(text: 'EXPENSE'),
            ],
          ),
        ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              _buildStylishBalanceCard(fundProvider.grandTotal),
              Expanded(
                child: fundProvider.isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Colors.tealAccent))
                    : TabBarView(
                        children: [
                          _buildMonthlyFundList(fundProvider, ballProvider, isAdmin, null),
                          _buildMonthlyFundList(fundProvider, ballProvider, isAdmin, 'INCOME'),
                          _buildMonthlyFundList(fundProvider, ballProvider, isAdmin, 'EXPENSE'),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
        floatingActionButton: isAdmin ? FloatingActionButton(
          onPressed: () => _showAddFundDialog(context),
          backgroundColor: Colors.tealAccent,
          child: const Icon(Icons.add, color: Colors.white),
        ) : null,
      ),
    );
  }

  Widget _buildStylishBalanceCard(double total) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF020C3B),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
          BoxShadow(color: Colors.greenAccent.withOpacity(0.05), blurRadius: 40, spreadRadius: -10),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TREASURY BALANCE', style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 14, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${total.toInt()}', style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 48, letterSpacing: 1)),
                      const SizedBox(width: 8),
                      Text('BDT', style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 18)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.greenAccent.withOpacity(0.2), Colors.greenAccent.withOpacity(0.05)]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
                ),
                child: const Icon(Icons.account_balance_rounded, color: Colors.greenAccent, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: Colors.white24, size: 14),
                const SizedBox(width: 8),
                Text('Real-time club savings from all sources', style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyFundList(FundProvider provider, BallProvider ballProv, bool isAdmin, String? typeFilter) {
    final filteredFunds = typeFilter == null 
        ? provider.funds 
        : provider.funds.where((f) => f.type == typeFilter).toList();

    if (filteredFunds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, color: Colors.white10, size: 80),
            const SizedBox(height: 20),
            Text(typeFilter == null ? 'No History Found' : 'No $typeFilter Entries', style: GoogleFonts.bebasNeue(color: Colors.white24, fontSize: 24)),
          ],
        ),
      );
    }

    Map<String, List<Fund>> monthGroups = {};
    for (var f in filteredFunds) {
      String monthKey = DateUtilsHelper.normalizeMonthYear(DateFormat('MMMM yyyy').format(f.date));
      monthGroups.putIfAbsent(monthKey, () => []);
      monthGroups[monthKey]!.add(f);
    }

    var allMonthKeys = monthGroups.keys.toList();
    DateTime minDate = DateTime(2026, 4, 1);
    var sortedMonths = allMonthKeys.where((m) {
      try {
        return DateFormat('MMMM yyyy').parse(m).isAfter(minDate.subtract(const Duration(days: 1)));
      } catch (_) { return true; }
    }).toList()..sort((a, b) {
      try {
        DateTime da = DateFormat('MMMM yyyy').parse(a);
        DateTime db = DateFormat('MMMM yyyy').parse(b);
        return db.compareTo(da);
      } catch (_) { return b.compareTo(a); }
    });

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: sortedMonths.length,
      itemBuilder: (context, mIndex) {
        String monthName = sortedMonths[mIndex];
        List<Fund> monthFunds = monthGroups[monthName]!;
        
        double monthInc = monthFunds.where((f) => f.type != 'EXPENSE').fold(0, (sum, f) => sum + f.amount);
        double monthExp = monthFunds.where((f) => f.type == 'EXPENSE').fold(0, (sum, f) => sum + f.amount);

        Map<String, List<Fund>> dailyGroups = {};
        for (var f in monthFunds) {
          String dateKey = DateFormat('yyyy-MM-dd').format(f.date);
          dailyGroups.putIfAbsent(dateKey, () => []);
          dailyGroups[dateKey]!.add(f);
        }
        var sortedDates = dailyGroups.keys.toList()..sort((a, b) => b.compareTo(a));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 15),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(width: 4, height: 20, decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 12),
                      Expanded(child: Text(monthName.toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 20, letterSpacing: 1))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryMini('INCOME', monthInc, Colors.greenAccent),
                      _buildSummaryMini('EXPENSE', monthExp, Colors.redAccent),
                      if (typeFilter == null)
                        _buildSummaryMini('NET', monthInc - monthExp, Colors.blueAccent),
                    ],
                  ),
                ],
              ),
            ),
            
            ...sortedDates.map((dateKey) {
              DateTime date = DateTime.parse(dateKey);
              List<Fund> items = dailyGroups[dateKey]!;

              return Container(
                margin: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF020C3B), Color(0xFF051970)]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        children: [
                          Text(DateFormat('MMM').format(date).toUpperCase(), style: GoogleFonts.bebasNeue(color: Colors.tealAccent, fontSize: 12)),
                          Text(DateFormat('dd').format(date), style: GoogleFonts.bebasNeue(color: Colors.white, fontSize: 22, height: 1)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        children: items.map((f) {
                          dynamic player;
                          if (f.playerId != null) {
                            try {
                              player = ballProv.players.firstWhere((p) => p.id == f.playerId);
                            } catch (_) {}
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white.withOpacity(0.05)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white10,
                                  backgroundImage: (player != null && player.photoUrl != '') 
                                      ? MemoryImage(base64Decode(player.photoUrl)) 
                                      : null,
                                  child: (player == null || player.photoUrl == '') 
                                      ? Text(f.name.isNotEmpty ? f.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 10, color: Colors.tealAccent)) 
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(f.name, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                                      if (f.note != null && f.note!.isNotEmpty)
                                        Text(f.note!, style: const TextStyle(color: Colors.white24, fontSize: 9)),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${f.type == 'EXPENSE' ? '-' : ''}${f.amount.toInt()} ৳', 
                                  style: GoogleFonts.bebasNeue(color: f.type == 'EXPENSE' ? Colors.redAccent : Colors.greenAccent, fontSize: 16)
                                ),
                                if (isAdmin) ...[
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => _showAddFundDialog(context, editFund: f),
                                    child: const Icon(Icons.edit_outlined, color: Colors.blueAccent, size: 16),
                                  ),
                                  const SizedBox(width: 10),
                                  GestureDetector(
                                    onTap: () => _confirmDeleteFund(context, provider, f),
                                    child: const Icon(Icons.delete_outline, color: Colors.white10, size: 16),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSummaryMini(String label, double val, Color color) {
    Color displayColor = color;
    if (label == 'INCOME') displayColor = const Color(0xFF00E676); // High-contrast success green
    if (label == 'EXPENSE') displayColor = const Color(0xFFFF5252); // High-contrast danger red
    if (label == 'NET') displayColor = val >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return Column(
      children: [
        Text(label, style: GoogleFonts.bebasNeue(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
        Text('${val.toInt()} ৳', style: GoogleFonts.bebasNeue(color: displayColor, fontSize: 16)),
      ],
    );
  }

  void _confirmDeleteFund(BuildContext context, FundProvider provider, Fund fund) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020C3B),
        title: Text('Delete Entry', style: GoogleFonts.bebasNeue(color: Colors.white)),
        content: Text('Remove this entry of ${fund.amount.toInt()}?', style: GoogleFonts.poppins(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final adminName = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';
              provider.deleteFund(fund.id!, adminName);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAddFundDialog(BuildContext context, {Fund? editFund}) {
    final ballProvider = Provider.of<BallProvider>(context, listen: false);
    final players = ballProvider.players;
    final nameController = TextEditingController(text: editFund?.name ?? '');
    final amountController = TextEditingController(text: editFund?.amount.toInt().toString() ?? '');
    final noteController = TextEditingController(text: editFund?.note ?? '');
    DateTime selectedDate = editFund?.date ?? DateTime.now();
    String entryType = editFund?.type ?? 'INCOME';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF020C3B),
          title: Text(editFund == null ? 'Add to Fund' : 'Edit Fund Entry', style: GoogleFonts.bebasNeue(color: Colors.white, letterSpacing: 1.2)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => entryType = 'INCOME'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: entryType == 'INCOME' ? Colors.greenAccent.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text('INCOME', style: GoogleFonts.bebasNeue(color: entryType == 'INCOME' ? Colors.greenAccent : Colors.white24)),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setDialogState(() => entryType = 'EXPENSE'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: entryType == 'EXPENSE' ? Colors.redAccent.withOpacity(0.2) : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text('EXPENSE', style: GoogleFonts.bebasNeue(color: entryType == 'EXPENSE' ? Colors.redAccent : Colors.white24)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') return const Iterable<String>.empty();
                    return players.where((p) => p.name.toLowerCase().contains(textEditingValue.text.toLowerCase())).map((p) => p.name);
                  },
                  onSelected: (String selection) { nameController.text = selection; },
                  fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextFormField(
                    controller: ctrl,
                    focusNode: focus,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDeco('NAME / SOURCE'),
                    onChanged: (v) => nameController.text = v,
                  ),
                  optionsViewBuilder: (ctx, onSelected, options) => Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: const Color(0xFF020C3B),
                      elevation: 4.0,
                      child: Container(
                        width: 250,
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (ctx, i) {
                            final name = options.elementAt(i);
                            final p = players.firstWhere((p) => p.name == name);
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.white10,
                                backgroundImage: p.photoUrl != '' ? MemoryImage(base64Decode(p.photoUrl)) : null,
                                child: p.photoUrl == '' ? Text(p.name[0], style: const TextStyle(fontSize: 10)) : null,
                              ),
                              title: Text(p.name, style: const TextStyle(color: Colors.white, fontSize: 13)),
                              onTap: () => onSelected(name),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('AMOUNT'),
                ),
                const SizedBox(height: 15),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setDialogState(() => selectedDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DATE: ${DateFormat('MMM dd, yyyy').format(selectedDate)}', style: const TextStyle(color: Colors.white70)),
                        const Icon(Icons.calendar_today, color: Colors.tealAccent, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: noteController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDeco('OPTIONAL NOTE'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent),
              onPressed: () async {
                String? selectedPlayerId;
                try {
                  selectedPlayerId = players.firstWhere((p) => p.name == nameController.text).id;
                } catch (_) {}

                if (nameController.text.isNotEmpty && amountController.text.isNotEmpty) {
                  final fund = Fund(
                    id: editFund?.id,
                    playerId: selectedPlayerId,
                    name: nameController.text,
                    amount: double.parse(amountController.text),
                    date: selectedDate,
                    note: noteController.text,
                    type: entryType,
                  );
                  final adminName = Provider.of<AuthProvider>(context, listen: false).currentUser?.name ?? 'Admin';
                  final success = editFund == null 
                      ? await Provider.of<FundProvider>(context, listen: false).addFund(fund, adminName)
                      : await Provider.of<FundProvider>(context, listen: false).updateFund(fund, adminName);
                  if (success) {
                    Navigator.pop(context);
                  }
                }
              },
              child: Text(editFund == null ? 'SAVE' : 'UPDATE', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white10)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.tealAccent)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );
  }
}
