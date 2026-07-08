import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

void main() => runApp(const DepremAnadoluPro());

class DepremAnadoluPro extends StatelessWidget {
  const DepremAnadoluPro({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ANADOLU RADAR v1.0',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xff05070c),
      ),
      home: const RadarMerkeziEkran(),
    );
  }
}

class RadarMerkeziEkran extends StatefulWidget {
  const RadarMerkeziEkran({super.key});

  @override
  State<RadarMerkeziEkran> createState() => _RadarMerkeziEkranState();
}

class _RadarMerkeziEkranState extends State<RadarMerkeziEkran> with SingleTickerProviderStateMixin {
  List<dynamic> _depremler = [];
  bool _yukleniyor = true;
  Timer? _timer;
  late AnimationController _pulseController;
  final AudioPlayer _audio = AudioPlayer();
  String? _sonId;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    
    _veriYenile();
    _timer = Timer.periodic(const Duration(seconds: 4), (t) => _veriYenile());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audio.dispose();
    super.dispose();
  }

  Future<void> _veriYenile() async {
    try {
      final res = await http.get(Uri.parse('https://api.orhanaydogdu.com.tr/deprem/kandilli/live'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final List<dynamic> liste = data['result'];
        
        // 3.5 altındaki küçük depremleri filtreliyoruz
        final filtreli = liste.where((d) => double.parse(d['mag'].toString()) >= 3.5).toList();

        if (filtreli.isNotEmpty) {
          final enSon = filtreli.first;
          double mag = double.parse(enSon['mag'].toString());
          if (_sonId != enSon['_id']) {
            _sonId = enSon['_id'];
            if (mag >= 4.5) {
              _sirenCal();
              _acilDurumEkrani(enSon['title'], mag.toString());
            }
          }
        }
        setState(() {
          _depremler = filtreli;
          _yukleniyor = false;
        });
      }
    } catch (e) {
      debugPrint("Radar hatası: $e");
    }
  }

  void _sirenCal() async {
    await _audio.play(AssetSource('siren.mp3'));
  }

  void _acilDurumEkrani(String yer, String siddet) {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      pageBuilder: (context, __, ___) {
        return Scaffold(
          backgroundColor: const Color(0xff1a0003),
          body: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: AcilDurumArkaPlanPainter())),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.gpp_maybe, size: 140, color: Color(0xffff0055)),
                    const SizedBox(height: 20),
                    const Text("SİSMİK ŞOK DALGASI", style: TextStyle(fontSize: 32, fontWeight: FontWeight.black, color: Colors.white, letterSpacing: 3)),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xffff0055), width: 2),
                      ),
                      child: Column(
                        children: [
                          Text(yer, style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          const SizedBox(height: 10),
                          Text("ŞİDDET: $siddet", style: const TextStyle(fontSize: 36, color: Color(0xffff0055), fontWeight: FontWeight.black)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xffff0055),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 18),
                        shape: const LinearBorder(),
                      ),
                      onPressed: () {
                        _audio.stop();
                        Navigator.pop(context);
                      },
                      child: const Text("SİRENİ SUSTUR", style: TextStyle(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _yukleniyor
          ? const Center(child: Text("SİSMİK RADAR BAŞLATILIYOR...", style: TextStyle(color: Color(0xff00ffaa), letterSpacing: 2)))
          : Column(
              children: [
                Expanded(
                  flex: 6,
                  child: AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) {
                      return Container(
                        margin: const EdgeInsets.only(top: 40, left: 15, right: 15, bottom: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xff080c14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xff1f3d68), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: CustomPaint(
                            painter: SismikRadarPainter(
                              depremler: _depremler,
                              animasyonDegeri: _pulseController.value,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: const BoxDecoration(
                      color: Color(0xff06090e),
                      border: Border(top: BorderSide(color: Color(0xff142238), width: 2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.between,
                          children: [
                            Text("ANLIK VERİ AKIŞI (M >= 3.5)", style: TextStyle(color: Color(0xff5575a5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                            Text("DURUM: AKTİF", style: TextStyle(color: Color(0xff00ffaa), fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _depremler.length,
                            itemBuilder: (context, index) {
                              final d = _depremler[index];
                              double mag = double.parse(d['mag'].toString());
                              bool kritik = mag >= 4.5;
                              
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: kritik ? const Color(0xff22050b) : const Color(0xff0b111a),
                                  border: Border.all(color: kritik ? const Color(0xffff0055).withOpacity(0.4) : const Color(0xff1a2c46)),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      mag.toString(),
                                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.black, color: kritik ? const Color(0xffff0055) : const Color(0xff00e5ff)),
                                    ),
                                    const SizedBox(width: 15),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                          const SizedBox(height: 3),
                                          Text("Derinlik: ${d['depth']} km | Zaman: ${d['date'].toString().substring(11, 16)}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.radar, size: 16, color: kritik ? const Color(0xffff0055) : const Color(0xff5575a5)),
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
              ],
            ),
    );
  }
}

class SismikRadarPainter extends CustomPainter {
  final List<dynamic> depremler;
  final double animasyonDegeri;
  SismikRadarPainter({required this.depremler, required this.animasyonDegeri});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintGrid = Paint()..color = const Color(0xff101c30)..style = PaintingStyle.stroke..strokeWidth = 1;
    final paintRadarLine = Paint()..color = const Color(0xff00ffaa).withOpacity(0.15)..style = PaintingStyle.stroke..strokeWidth = 1.5;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (size.width / 4.5) * i, paintGrid);
    }
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paintGrid);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paintGrid);

    canvas.drawCircle(center, size.width * 0.45 * animasyonDegeri, paintRadarLine);

    if (depremler.isEmpty) return;

    for (var i = 0; i < depremler.length; i++) {
      var d = depremler[i];
      double mag = double.parse(d['mag'].toString());
      List<dynamic> coords = d['geojson']['coordinates'];
      double lon = double.parse(coords[0].toString()); 
      double lat = double.parse(coords[1].toString()); 

      double x = size.width * (0.15 + ((lon - 26) / (45 - 26)) * 0.7);
      double y = size.height * (0.85 - ((lat - 36) / (42 - 36)) * 0.7);
      Offset noktaDurumu = Offset(x, y);

      bool isKritik = mag >= 4.5;
      Color anaRenk = isKritik ? const Color(0xffff0055) : const Color(0xff00e5ff);

      canvas.drawCircle(noktaDurumu, kritikHalkaBoyutu(mag), Paint()..color = anaRenk);
      canvas.drawCircle(noktaDurumu, kritikHalkaBoyutu(mag) + 4, Paint()..color = anaRenk.withOpacity(0.3)..style = PaintingStyle.stroke);

      if (i == 0) {
        double dalgaBoyu = 60 * animasyonDegeri;
        canvas.drawCircle(noktaDurumu, dalgaBoyu, Paint()..color = anaRenk.withOpacity(1 - animasyonDegeri)..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  double kritikHalkaBoyutu(double mag) {
    if (mag >= 5.0) return 9.0;
    if (mag >= 4.5) return 7.0;
    return 4.5;
  }

  @override
  bool shouldRepaint(covariant SismikRadarPainter oldDelegate) => true;
}

class AcilDurumArkaPlanPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xffff0055).withOpacity(0.04)..strokeWidth = 3;
    for (var i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i.toDouble(), 0), Offset(i.toDouble() - 100, size.height), paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
