import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final _searchCtr = TextEditingController(text: 'Dhaka');
  bool loading = false;
  String? error;
  String? _resolvedCity;

  //Current
  double? _tempC;
  double? _windKph;
  int? _wCode;
  String? _wText;

  double? _hi, _lo;

  List<_Hourly> _hourlies = [];
  List<_Daily> _dailies = [];

  // --------network---------
  Future<({String? city, double? lat, double? lon})> geoLocation(String city) async {
    try {
      final url = Uri.parse(
          'https://geocoding-api.open-meteo.com/v1/search?name=$city&count=1&format=json');
      final res = await http.get(url);
      if (res.statusCode != 200) throw Exception('Geocoding failed ${res.statusCode}');
      final deData = jsonDecode(res.body) as Map<String, dynamic>;
      final results = (deData['results'] as List?) ?? [];
      if (results.isEmpty) throw Exception('City Not found');

      final m = results.first as Map<String, dynamic>;
      final lat = (m['latitude'] as num).toDouble();
      final lon = (m['longitude'] as num).toDouble();
      final name = '${m['name']} ${m['country']}';

      return (city: name, lat: lat, lon: lon);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<void> _fetch(String city) async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final getGeoData = await geoLocation(city);

      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast'
              '?latitude=${getGeoData.lat}&longitude=${getGeoData.lon}'
              '&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset'
              '&hourly=temperature_2m,weather_code,wind_speed_10m'
              '&current=temperature_2m,weather_code,wind_speed_10m'
              '&forecast_days=10'
              '&timezone=Asia%2FDhaka'
      );

      final res = await http.get(url);
      if (res.statusCode != 200) throw Exception('Weather API failed ${res.statusCode}');
      final deData = jsonDecode(res.body) as Map<String, dynamic>;

      // current
      final current = deData['current'] as Map<String, dynamic>;
      final tempC = (current['temperature_2m'] as num).toDouble();
      final windKph = (current['wind_speed_10m'] as num).toDouble();
      final wCode = (current['weather_code'] as num).toInt();

      // hourly
      final hourly = deData['hourly'] as Map<String, dynamic>;
      final hTimes = List<String>.from(hourly['time'] as List);
      final hTemps = List<num>.from(hourly['temperature_2m'] as List);
      final hCodes = List<num>.from(hourly['weather_code'] as List);
      final hWinds = List<num>.from(hourly['wind_speed_10m'] as List);

      final outHourly = <_Hourly>[];
      for (var i = 0; i < hTimes.length; i++) {
        outHourly.add(_Hourly(
          DateTime.parse(hTimes[i]),
          (hTemps[i]).toDouble(),
          (hCodes[i]).toInt(),
          (hWinds[i]).toDouble(),
        ));
      }

      // daily
      final daily = deData['daily'] as Map<String, dynamic>;
      final dTimes = List<String>.from(daily['time'] as List);
      final dMax = List<num>.from(daily['temperature_2m_max'] as List);
      final dMin = List<num>.from(daily['temperature_2m_min'] as List);

      final outDaily = <_Daily>[];
      for (var i = 0; i < dTimes.length; i++) {
        outDaily.add(
          _Daily(
            DateTime.parse(dTimes[i]),
            (dMin[i]).toDouble(),
            (dMax[i]).toDouble(),
          ),
        );
      }

      // H & L today
      _hi = outDaily.first.tMax;
      _lo = outDaily.first.tMin;

      setState(() {
        _resolvedCity = getGeoData.city;
        _tempC = tempC;
        _wCode = wCode;
        _wText = _codeToText(wCode);
        _windKph = windKph;
        _hourlies = outHourly;
        _dailies = outDaily;
      });
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      setState(() => loading = false);
    }
  }

  String _codeToText(int? c) {
    if (c == null) return '--';
    if (c == 0) return 'Clear Sky';
    if ([1, 2, 3].contains(c)) return 'Mainly Clear';
    if ([45, 48].contains(c)) return 'Fog';
    if ([51, 53, 55, 56, 57].contains(c)) return 'Drizzle';
    if ([61, 63, 65, 66, 67].contains(c)) return 'Rain';
    if ([71, 73, 75, 77].contains(c)) return 'Snow';
    if ([80, 81, 82].contains(c)) return 'Rain Showers';
    if ([85, 86].contains(c)) return 'Snow Showers';
    if (c == 95) return 'Thunderstorm';
    if (c == 96) return 'Hail';
    return 'Cloudy';
  }

  IconData _codeToIcon(int? c) {
    if (c == 0) return Icons.sunny;
    if ([1, 2, 3].contains(c)) return Icons.cloud;
    if ([45, 48].contains(c)) return Icons.cloud;
    if ([51, 53, 55, 56, 57].contains(c)) return Icons.grain_sharp;
    if ([61, 63, 65, 66, 67].contains(c)) return Icons.water_drop;
    if ([71, 73, 75, 77].contains(c)) return Icons.ac_unit;
    if ([80, 81, 82].contains(c)) return Icons.deblur_rounded;
    if ([85, 86].contains(c)) return Icons.snowing;
    if (c == 95 || c == 96) return Icons.thunderstorm;
    return Icons.cloud;
  }

  @override
  void initState() {
    _fetch('Dhaka');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _fetch(_searchCtr.text),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.blue,
                  Colors.blueAccent,
                  Colors.white70,
                ]),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // SEARCH BAR
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        style: const TextStyle(color: Colors.white),
                        controller: _searchCtr,
                        onSubmitted: (v) => _fetch(v),
                        decoration: InputDecoration(
                          labelText: 'Enter city ( e.g. Dhaka )',
                          labelStyle: const TextStyle(color: Colors.white),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.5)),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: loading ? null : () => _fetch(_searchCtr.text),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white70,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                      child: const Text(
                        'Go',
                        style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                if (loading) const LinearProgressIndicator(),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 8),

                // LOCATION + MAIN INFO
                Column(
                  children: [
                    const Text(
                      'MY LOCATION',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _resolvedCity ?? 'Bangladesh',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                          color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Icon(_codeToIcon(_wCode),
                        size: 90, color: Colors.white70),
                  ],
                ),

                const SizedBox(height: 10),

                if (_tempC != null)
                  Center(
                    child: Text(
                      '${_tempC!.toStringAsFixed(0)} °C',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 96,
                          color: Colors.white70),
                    ),
                  ),

                if (_hi != null && _lo != null)
                  Center(
                    child: Text(
                      'H: ${_hi!.toStringAsFixed(0)}°   L: ${_lo!.toStringAsFixed(0)}°',
                      style: const TextStyle(
                          fontSize: 20, color: Colors.white70),
                    ),
                  ),

                const SizedBox(height: 12),

                // SUMMARY CARD
                if (_windKph != null)
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                          '${_wText ?? "Clear"} conditions likely today. Wind up to ${_windKph!.toStringAsFixed(1)} km/h.',
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),

                const SizedBox(height: 12),

                // HOURLY FORECAST
                if (_hourlies.isNotEmpty)
                  Card(
                    color: Colors.white,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "24-Hour Forecast",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 120,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: 24,
                              itemBuilder: (_, i) {
                                final h = _hourlies[i];
                                final label =
                                i == 0 ? 'Now' : '${h.t.hour}';
                                return Container(
                                  width: 70,
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 4),
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        label,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Icon(_codeToIcon(h.code),
                                          color: Colors.blue, size: 24),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${h.temp.toStringAsFixed(0)}°',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${h.wind.toStringAsFixed(0)}km/h',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 20),

                // DAILY FORECAST
                if (_dailies.isNotEmpty)
                  Card(
                    color: Colors.white,
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            "10-Day Forecast",
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(),

                        // --------------------------
                        // DAILY ROW WITH PROGRESS BAR
                        // --------------------------
                        ..._dailies.asMap().entries.map((entry) {
                          final index = entry.key;
                          final d = entry.value;

                          final dayText = index == 0
                              ? "Today"
                              : ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                          [d.date.weekday % 7];

                          // Find most frequent weather code for the day
                          final dailyCode = () {
                            final hForDay = _hourlies.where((h) =>
                            h.t.year == d.date.year &&
                                h.t.month == d.date.month &&
                                h.t.day == d.date.day);

                            if (hForDay.isEmpty) return _wCode ?? 1;

                            final freq = <int, int>{};
                            for (final h in hForDay) {
                              freq[h.code] = (freq[h.code] ?? 0) + 1;
                            }

                            return freq.entries
                                .reduce((a, b) =>
                            a.value > b.value ? a : b)
                                .key;
                          }();

                          // progress based on global hi/lo
                          final progress = ((d.tMax - _lo!) / (_hi! - _lo!))
                              .clamp(0.0, 1.0);

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            child: Row(
                              children: [
                                // DAY NAME
                                SizedBox(
                                  width: 60,
                                  child: Text(
                                    dayText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                                // ICON
                                Icon(
                                  _codeToIcon(dailyCode),
                                  color: Colors.blue,
                                  size: 26,
                                ),

                                const SizedBox(width: 12),

                                // PROGRESS BAR
                                // PROGRESS BAR (Right → Left)
                                Expanded(
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      Align(
                                        alignment: Alignment.centerRight,  // 👈 RIGHT SIDE START
                                        child: FractionallySizedBox(
                                          widthFactor: progress,
                                          alignment: Alignment.centerRight,
                                          child: Container(
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Colors.orange,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),


                                const SizedBox(width: 12),

                                // MAX TEMP
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${d.tMax.toStringAsFixed(0)}°',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // MIN TEMP
                                SizedBox(
                                  width: 40,
                                  child: Text(
                                    '${d.tMin.toStringAsFixed(0)}°',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList()
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Hourly {
  final DateTime t;
  final double temp;
  final int code;
  final double wind;

  _Hourly(this.t, this.temp, this.code, this.wind);
}

class _Daily {
  final DateTime date;
  final double tMin, tMax;

  _Daily(this.date, this.tMin, this.tMax);
}
