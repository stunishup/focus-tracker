import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:home_widget/home_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await HomeWidget.setAppGroupId('com.profitbutton.focus');
  } catch (e) {
    // ignore
  }
  runApp(const FocusApp());
}

class WeekRecord {
  final String weekStart;
  final String weekEnd;
  final int hours;
  final int goal;
  final int used;
  final int lost;
  final int over;
  final bool full;

  WeekRecord({
    required this.weekStart, required this.weekEnd,
    required this.hours, required this.goal,
    required this.used, required this.lost,
    required this.over, required this.full,
  });

  Map<String, dynamic> toJson() => {
    'weekStart': weekStart, 'weekEnd': weekEnd,
    'hours': hours, 'goal': goal, 'used': used,
    'lost': lost, 'over': over, 'full': full,
  };

  factory WeekRecord.fromJson(Map<String, dynamic> j) => WeekRecord(
    weekStart: j['weekStart'], weekEnd: j['weekEnd'],
    hours: j['hours'], goal: j['goal'], used: j['used'],
    lost: j['lost'], over: j['over'], full: j['full'],
  );
}

class AppState extends ChangeNotifier {
  int goal = 10;
  String currentWeekStart = '';
  int currentHours = 0;
  int totalUsed = 0;
  int totalLost = 0;
  int totalOvertime = 0;
  int streak = 0;
  int fullWeeks = 0;
  int totalWeeks = 0;
  List<WeekRecord> history = [];
  bool _loaded = false;

  int get overtime => (currentHours - goal).clamp(0, 999);
  int get risk => (goal - currentHours).clamp(0, goal);
  bool get weekDone => currentHours >= goal;
  double get progress => goal > 0 ? (currentHours / goal).clamp(0.0, 1.0) : 0.0;

  String get weekEnd {
    if (currentWeekStart.isEmpty) return '';
    final start = _parseDate(currentWeekStart);
    final end = start.add(const Duration(days: 6));
    return _formatDate(end);
  }

  String get weekStartFormatted {
    if (currentWeekStart.isEmpty) return '—';
    return _formatDate(_parseDate(currentWeekStart));
  }

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      goal = prefs.getInt('goal') ?? 10;
      currentWeekStart = prefs.getString('currentWeekStart') ?? _getWeekStart(DateTime.now());
      currentHours = prefs.getInt('currentHours') ?? 0;
      totalUsed = prefs.getInt('totalUsed') ?? 0;
      totalLost = prefs.getInt('totalLost') ?? 0;
      totalOvertime = prefs.getInt('totalOvertime') ?? 0;
      streak = prefs.getInt('streak') ?? 0;
      fullWeeks = prefs.getInt('fullWeeks') ?? 0;
      totalWeeks = prefs.getInt('totalWeeks') ?? 0;
      final histJson = prefs.getString('history') ?? '[]';
      final histList = jsonDecode(histJson) as List;
      history = histList.map((e) => WeekRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      currentWeekStart = _getWeekStart(DateTime.now());
    }
    _loaded = true;
    _checkAndCloseWeek();
    notifyListeners();
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('goal', goal);
      await prefs.setString('currentWeekStart', currentWeekStart);
      await prefs.setInt('currentHours', currentHours);
      await prefs.setInt('totalUsed', totalUsed);
      await prefs.setInt('totalLost', totalLost);
      await prefs.setInt('totalOvertime', totalOvertime);
      await prefs.setInt('streak', streak);
      await prefs.setInt('fullWeeks', fullWeeks);
      await prefs.setInt('totalWeeks', totalWeeks);
      await prefs.setString('history', jsonEncode(history.map((e) => e.toJson()).toList()));
    } catch (e) {
      // ignore
    }
    await _updateWidget();
  }

  Future<void> _updateWidget() async {
    try {
      final riskText = weekDone
          ? overtime > 0 ? 'Жодної не втрачено +$overtime ⚡' : 'Жодної години не втрачено ✓'
          : 'Ризик втратити $risk ${_hoursWord(risk)}';
      await HomeWidget.saveWidgetData<String>('risk_text', riskText);
      await HomeWidget.saveWidgetData<bool>('week_done', weekDone);
      await HomeWidget.saveWidgetData<int>('current_hours', currentHours.clamp(0, goal));
      await HomeWidget.saveWidgetData<int>('goal', goal);
      await HomeWidget.saveWidgetData<int>('overtime', overtime);
      await HomeWidget.saveWidgetData<int>('total_used', totalUsed);
      await HomeWidget.saveWidgetData<int>('total_lost', totalLost);
      await HomeWidget.saveWidgetData<int>('total_overtime', totalOvertime);
      await HomeWidget.saveWidgetData<String>('week_dates', '$weekStartFormatted — $weekEnd');
      await HomeWidget.updateWidget(androidName: 'FocusWidgetSmall');
      await HomeWidget.updateWidget(androidName: 'FocusWidgetLarge');
    } catch (e) {
      // ignore
    }
  }

  void _checkAndCloseWeek() {
    if (currentWeekStart.isEmpty) {
      currentWeekStart = _getWeekStart(DateTime.now());
      return;
    }
    final todayWeekStart = _getWeekStart(DateTime.now());
    if (currentWeekStart != todayWeekStart) {
      final used = currentHours.clamp(0, goal);
      final lost = (goal - currentHours).clamp(0, goal);
      final over = (currentHours - goal).clamp(0, 999);
      totalUsed += used; totalLost += lost; totalOvertime += over; totalWeeks += 1;
      final isFull = currentHours >= goal;
      if (isFull) { streak += 1; fullWeeks += 1; } else { streak = 0; }
      final startD = _parseDate(currentWeekStart);
      final endD = startD.add(const Duration(days: 6));
      history.insert(0, WeekRecord(
        weekStart: currentWeekStart, weekEnd: _formatDate(endD),
        hours: currentHours, goal: goal,
        used: used, lost: lost, over: over, full: isFull,
      ));
      currentWeekStart = todayWeekStart;
      currentHours = 0;
    }
  }

  Future<void> addHour() async {
    _checkAndCloseWeek();
    currentHours += 1;
    notifyListeners();
    await _save();
  }

  Future<void> setHours(int val) async {
    if (val < 0) return;
    _checkAndCloseWeek();
    currentHours = val;
    notifyListeners();
    await _save();
  }

  Future<void> setGoal(int val) async {
    if (val < 1 || val > 80) return;
    goal = val;
    notifyListeners();
    await _save();
  }

  Future<void> resetAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      // ignore
    }
    goal = 10; currentWeekStart = _getWeekStart(DateTime.now());
    currentHours = 0; totalUsed = 0; totalLost = 0; totalOvertime = 0;
    streak = 0; fullWeeks = 0; totalWeeks = 0; history = [];
    notifyListeners();
    await _save();
  }

  // Без intl — ручне форматування щоб уникнути краша локалі
  static String _getWeekStart(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final start = d.subtract(Duration(days: d.weekday - 1));
    return '${start.year}-${start.month.toString().padLeft(2,'0')}-${start.day.toString().padLeft(2,'0')}';
  }

  static DateTime _parseDate(String s) {
    final parts = s.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  static const _months = ['', 'січ', 'лют', 'бер', 'кві', 'тра', 'чер',
                               'лип', 'сер', 'вер', 'жов', 'лис', 'гру'];

  static String _formatDate(DateTime d) => '${d.day} ${_months[d.month]}';

  static String _hoursWord(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return 'годин';
    switch (n % 10) {
      case 1: return 'годину';
      case 2: case 3: case 4: return 'години';
      default: return 'годин';
    }
  }
}

// ─── APP ─────────────────────────────────────────────────────────────────────

class FocusApp extends StatefulWidget {
  const FocusApp({super.key});
  @override
  State<FocusApp> createState() => _FocusAppState();
}

class _FocusAppState extends State<FocusApp> with WidgetsBindingObserver {
  late AppState _appState;

  @override
  void initState() {
    super.initState();
    _appState = AppState()..load();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _appState.load(); // re-read from SharedPreferences when app comes to foreground
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _appState,
      child: MaterialApp(
        title: 'Фокус',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0D0D0F),
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFF7C5CFC),
            surface: const Color(0xFF141417),
            onPrimary: Colors.white,
            onSurface: Colors.white,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF7C5CFC),
            ),
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class ChangeNotifierProvider<T extends ChangeNotifier> extends StatefulWidget {
  final T Function(BuildContext) create;
  final Widget child;
  const ChangeNotifierProvider({super.key, required this.create, required this.child});
  @override
  State<ChangeNotifierProvider<T>> createState() => _CNPState<T>();
  static T of<T extends ChangeNotifier>(BuildContext context) {
    return context.findAncestorStateOfType<_CNPState<T>>()!.notifier;
  }
}

class _CNPState<T extends ChangeNotifier> extends State<ChangeNotifierProvider<T>> {
  late T notifier;
  @override
  void initState() {
    super.initState();
    notifier = widget.create(context);
    notifier.addListener(() { if (mounted) setState(() {}); });
  }
  @override
  void dispose() { notifier.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => widget.child;
}

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) {
    final state = ChangeNotifierProvider.of<AppState>(context);
    final pages = [
      HomeTab(state: state),
      StatsTab(state: state),
      HistoryTab(state: state),
      SettingsTab(state: state),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        backgroundColor: const Color(0xFF141417),
        indicatorColor: const Color(0xFF7C5CFC).withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Тиждень'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'Статистика'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Історія'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Налаштування'),
        ],
      ),
    );
  }
}

// ─── HOME TAB ────────────────────────────────────────────────────────────────

class HomeTab extends StatelessWidget {
  final AppState state;
  const HomeTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _card(children: [
            _label('ПОТОЧНИЙ ТИЖДЕНЬ'),
            const SizedBox(height: 4),
            Text('${state.weekStartFormatted} — ${state.weekEnd}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B80))),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('${state.currentHours.clamp(0, state.goal)}',
                  style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w700, color: Colors.white)),
                const Text(' / ', style: TextStyle(fontSize: 28, color: Color(0xFF6B6B80))),
                Text('${state.goal}', style: const TextStyle(fontSize: 28, color: Color(0xFF6B6B80))),
                const SizedBox(width: 6),
                const Text('год', style: TextStyle(fontSize: 14, color: Color(0xFF6B6B80))),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: state.progress, minHeight: 10,
                backgroundColor: const Color(0xFF1C1C22),
                valueColor: AlwaysStoppedAnimation<Color>(
                  state.weekDone ? const Color(0xFF22C55E) : const Color(0xFF7C5CFC),
                ),
              ),
            ),
            if (state.weekDone) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.1),
                  border: Border.all(color: const Color(0xFF22C55E).withOpacity(0.25)),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('✓  ТИЖДЕНЬ ВИКОНАНО',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF22C55E))),
              ),
            ],
            if (state.overtime > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withOpacity(0.08),
                  border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  const Text('Понаднормово', style: TextStyle(fontSize: 13, color: Color(0xFFF59E0B))),
                  const Spacer(),
                  Text('+${state.overtime} год',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFF59E0B))),
                ]),
              ),
            ],
            if (!state.weekDone) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.06),
                  border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Container(width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                  const SizedBox(width: 8),
                  Text('Ризик втратити ${state.risk} ${AppState._hoursWord(state.risk)}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: state.addHour,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CFC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('+ 1 година',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _showManualInput(context, state),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B6B80),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF2A2A35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Ввести вручну',
                style: TextStyle(color: Color(0xFF6B6B80))),
            ),
          ),
        ]),
      ),
    );
  }

  void _showManualInput(BuildContext context, AppState state) {
    final ctrl = TextEditingController(text: '${state.currentHours}');
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141417),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 40,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Ввести кількість годин',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.white)),
          const SizedBox(height: 16),
          TextField(
            controller: ctrl, autofocus: true,
            keyboardType: TextInputType.number, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 32, color: Colors.white),
            decoration: InputDecoration(
              filled: true, fillColor: const Color(0xFF1C1C22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF2A2A35)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF6B6B80),
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFF2A2A35)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Скасувати', style: TextStyle(color: Color(0xFF6B6B80))),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () {
                final val = int.tryParse(ctrl.text);
                if (val != null && val >= 0) { state.setHours(val); Navigator.pop(context); }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C5CFC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Зберегти', style: TextStyle(color: Colors.white)),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ─── STATS TAB ───────────────────────────────────────────────────────────────

class StatsTab extends StatelessWidget {
  final AppState state;
  const StatsTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final avg = state.totalWeeks > 0
        ? (state.totalUsed / state.totalWeeks).toStringAsFixed(1) : '—';
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.4,
            children: [
              _statCard('✅', '${state.totalUsed}', 'Використано год', const Color(0xFF22C55E)),
              _statCard('❌', '${state.totalLost}', 'Втрачено год', const Color(0xFFEF4444)),
              _statCard('⚡', '${state.totalOvertime}', 'Понаднормово год', const Color(0xFFF59E0B)),
              _statCard('🔥', '${state.streak}', 'Серія тижнів', const Color(0xFF9D7DFF)),
            ],
          ),
          const SizedBox(height: 16),
          _card(children: [
            _label('ЗАГАЛЬНА КАРТИНА'),
            _row('Тижнів завершено', '${state.totalWeeks}', Colors.white),
            _row('Тижнів виконано повністю', '${state.fullWeeks}', const Color(0xFF22C55E)),
            _row('Середнє год/тиждень', avg, Colors.white),
          ]),
          if (state.totalLost > 0) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.06),
                border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.15)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('📉  БЕЗПОВОРОТНО ВТРАЧЕНО',
                  style: TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Text.rich(TextSpan(
                  style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.white),
                  children: [
                    TextSpan(text: '${state.totalLost} год',
                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                    const TextSpan(text: ' безповоротно пішло не на агенцію.\nЦе '),
                    TextSpan(text: '${(state.totalLost / 8).toStringAsFixed(1)} роб. днів',
                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                    const TextSpan(text: ' або '),
                    TextSpan(text: '${(state.totalLost / 40).toStringAsFixed(1)} тижнів',
                      style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                    const TextSpan(text: ' повного фокусу,\nяких більше немає.'),
                  ],
                )),
              ]),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _statCard(String icon, String val, String label, Color color) =>
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        border: Border.all(color: const Color(0xFF2A2A35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(height: 8),
        Text(val, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B6B80))),
      ]),
    );

  Widget _row(String label, String val, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(children: [
      Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF6B6B80))),
      const Spacer(),
      Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: color)),
    ]),
  );
}

// ─── HISTORY TAB ─────────────────────────────────────────────────────────────

class HistoryTab extends StatelessWidget {
  final AppState state;
  const HistoryTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: state.history.isEmpty
        ? const Center(child: Text('Ще немає закритих тижнів',
            style: TextStyle(color: Color(0xFF6B6B80))))
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: state.history.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final w = state.history[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C22),
                  border: Border.all(color: const Color(0xFF2A2A35)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Container(width: 10, height: 10,
                    decoration: BoxDecoration(
                      color: w.full ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    )),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${w.weekStart} — ${w.weekEnd}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B80))),
                    Text('${w.hours} / ${w.goal} год',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(w.full ? '✓ виконано' : '✗ ${w.lost} год недобрано',
                      style: TextStyle(fontSize: 11,
                          color: w.full ? const Color(0xFF22C55E) : const Color(0xFFEF4444))),
                    if (w.over > 0)
                      Text('+${w.over} понаднормово',
                        style: const TextStyle(fontSize: 11, color: Color(0xFFF59E0B))),
                  ]),
                ]),
              );
            },
          ),
    );
  }
}

// ─── SETTINGS TAB ────────────────────────────────────────────────────────────

class SettingsTab extends StatelessWidget {
  final AppState state;
  const SettingsTab({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 8),
          _card(children: [
            _label('НОРМА'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Годин на тиждень', style: TextStyle(fontSize: 15, color: Colors.white)),
                  SizedBox(height: 2),
                  Text('Мінімум для виконання норми',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6B6B80))),
                ])),
                Row(children: [
                  _iconBtn(Icons.remove, () => state.setGoal(state.goal - 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('${state.goal}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  _iconBtn(Icons.add, () => state.setGoal(state.goal + 1)),
                ]),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          _card(children: [
            _label('СКИДАННЯ'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(children: [
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Скинути всі дані', style: TextStyle(fontSize: 15, color: Colors.white)),
                  SizedBox(height: 2),
                  Text('Незворотна дія', style: TextStyle(fontSize: 12, color: Color(0xFF6B6B80))),
                ])),
                TextButton(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: const Color(0xFF141417),
                        title: const Text('Скинути дані?', style: TextStyle(color: Colors.white)),
                        content: const Text('Всі записи будуть видалені назавжди.',
                          style: TextStyle(color: Color(0xFF6B6B80))),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false),
                            child: const Text('Скасувати')),
                          TextButton(onPressed: () => Navigator.pop(context, true),
                            child: const Text('Скинути',
                              style: TextStyle(color: Color(0xFFEF4444)))),
                        ],
                      ),
                    );
                    if (ok == true) state.resetAll();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withOpacity(0.1),
                    foregroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Скинути', style: TextStyle(color: Color(0xFFEF4444))),
                ),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        border: Border.all(color: const Color(0xFF2A2A35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    ),
  );
}

// ─── SHARED WIDGETS ──────────────────────────────────────────────────────────

Widget _card({required List<Widget> children}) => Container(
  width: double.infinity,
  padding: const EdgeInsets.all(20),
  decoration: BoxDecoration(
    color: const Color(0xFF141417),
    border: Border.all(color: const Color(0xFF2A2A35)),
    borderRadius: BorderRadius.circular(16),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
);

Widget _label(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(text, style: const TextStyle(
      fontSize: 11, letterSpacing: 0.1,
      color: Color(0xFF6B6B80), fontWeight: FontWeight.w500)),
);
