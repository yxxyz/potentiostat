import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:potentiostat/utils/helper.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:math';

// widget class
class EISGraphPage extends StatefulWidget {
  final Function(int, [BluetoothDevice?]) updatePageIndex;
  // final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  final BluetoothCharacteristic? characteristic; 
  final String technique;
  final bool calibrationEnabled;
  final Map<String, int> pageIndices;

  const EISGraphPage({
    super.key, 
    required this.updatePageIndex,
    // required this.updateCharacteristic,
    required this.device,
    required this.characteristic,
    required this.calibrationEnabled,
    required this.technique,
    required this.pageIndices,
  });

  @override
  _EISGraphPageState createState() => _EISGraphPageState(); 
}

class _EISGraphPageState extends State<EISGraphPage> {
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothDevice? _connectedDevice;

  late String selectedTechnique; 
  bool isStreaming = false;
  StreamSubscription<List<int>>? _subscription;

  BuildContext? calibrationDialogContext;
  BuildContext? zunknownDialogContext;

  // stores elements of type FlSpot (x, y) for graph data points
  List<FlSpot> _impedancePoints = [];
  List<FlSpot> _impedanceAbsPoints = [];
  List<FlSpot> _phasePoints = [];
  
  // single color for the line
  final Color _lineColor = Colors.blue;
  
  // // Get min/max values for data points
  // double get minX {
  //   if (_dataPoints.isEmpty) {
  //     return -500;  // if empty return -500 as minimum x value
  //   }
  //   // return minimum x - 50 with a margin of 50
  //   return _dataPoints.map((spot) => spot.x).reduce((a, b) => a < b ? a : b) - 50;
  // }

  // double get maxX {
  //   if (_dataPoints.isEmpty) {
  //     return 500; // if empty return 500 as maximum x value
  //   }
  //   // return minimum x + 50 with a margin of 50
  //   return _dataPoints.map((spot) => spot.x).reduce((a, b) => a > b ? a : b) + 50;
  // }

  // double get minY {
  //   if (_dataPoints.isEmpty) {
  //     return -50; // if empty return -50 as minimum y value
  //   }
  //   // return minimum y * 1.2 with a margin of 20%
  //   return _dataPoints.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) * 1.2;
  // }

  // double get maxY {
  //   if (_dataPoints.isEmpty) {
  //     return 50;  // if empty return 50 as maximum y value
  //   }
  //   // return maximum y * 1.2 with a margin of 20%
  //   return _dataPoints.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.2;
  // }

  double getMinX(List<FlSpot> points) =>
    points.isEmpty ? -500 : points.map((e) => e.x).reduce(min);

  double getMaxX(List<FlSpot> points) =>
      points.isEmpty ? 500 : points.map((e) => e.x).reduce(max);

  double getMinY(List<FlSpot> points) =>
      points.isEmpty ? -50 : points.map((e) => e.y).reduce(min);

  double getMaxY(List<FlSpot> points) =>
      points.isEmpty ? 50 : points.map((e) => e.y).reduce(max);

  @override
  void initState() {
    super.initState();
    selectedTechnique = widget.technique;
  }  

  Future<void> startDataStream() async {
    _connectedDevice = widget.device;
    _writeCharacteristic = widget.characteristic;

    if (widget.calibrationEnabled) {
    // First alert
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: const Text(
            "Calibration Setup",
            style: TextStyle(
                color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: const Text(
            "Please connect 100Ω resistor.",
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
          ),
          actions: [
            TextButton(
              child: const Text("Start",
              style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              
              onPressed: () {
                Navigator.of(context).pop(); // close first alert
              },
            ),
          ],
        );
      },
    );

    

    // Second alert right after OK is pressed
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        calibrationDialogContext = ctx; // store dialog context
        return const AlertDialog(
          backgroundColor: const Color(0xFF121212),
          title: Text(
            "Calibration Running",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: Text(
            "Performing calibration with 100Ω resistor.",
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
          ),
        );
      },
    );
  }


    if (widget.characteristic == null) {
      print("⚠️ No characteristic found for listening!");
      return;
    }
    
    // cancel any existing subscription first
    _subscription?.cancel();
    
    // clear existing data points
    setState(() {
      _impedancePoints.clear();
      _impedanceAbsPoints.clear();
      _phasePoints.clear();
    });
    
    // enable notifications
    await enableNotifications(
      characteristic: widget.characteristic!,
      onACKReceived: (char) {
        print("✅ ACK received in GraphPage!");
      },
    );
    
    List<int> _packetBuffer = [];
    
    // subscribe to ble stream, function is triggered when new BLE data is sent
    // _subscription = widget.characteristic!.onValueReceived.listen((List<int> data) {
    //   if (data.isNotEmpty) {
    //     print("Raw data received: $data");
    //     String receivedText = String.fromCharCodes(data).trim().toUpperCase();
    //     print("Parsed text: '$receivedText'");

    //     if (receivedText == "CALDONE") {
    //       print("✅ Calibration done signal received from Arduino");

    //       // Close the dialog if still open
    //       if (calibrationDialogContext != null) {
    //         Navigator.of(calibrationDialogContext!, rootNavigator: true).pop();
    //         calibrationDialogContext = null; // clear reference
    //       }
    //       return;
    //     }

    //     if (receivedText == "ZDONE") {
    //       print("✅ Change zdone signal received from Arduino");

    //       // Close the dialog if still open
    //       if (zunknownDialogContext != null) {
    //         Navigator.of(zunknownDialogContext!, rootNavigator: true).pop();
    //         zunknownDialogContext = null; // clear reference
    //       }
    //       return;
    //     }

    //     // check for "DONE" first
    //     if (receivedText == "DONE") {
    //       print("✅ DONE signal received from Arduino");
    //       setState(() {
    //         isStreaming = false;
    //         _packetBuffer.clear();
    //       });
    //       _subscription?.cancel();
    //       _subscription = null;
    //       return;
    //     }

    //     // if not "DONE", treat as data packet
    //     parseGraphData(data, _packetBuffer);
    //   }
    // });

    _subscription = widget.characteristic!.onValueReceived.listen((List<int> data) {
    if (data.isNotEmpty) {
      final String receivedText = String.fromCharCodes(data).trim().toUpperCase();
      print("Parsed text: '$receivedText'");

      // ===== When calibration finishes =====
      if (receivedText == "CALDONE") {
        print("✅ Calibration done signal received from Arduino");

        // Close the calibration-running dialog if still open
        if (calibrationDialogContext != null) {
          if (mounted) {
            Navigator.of(calibrationDialogContext!, rootNavigator: true).pop();
          }
          calibrationDialogContext = null;
        }

        // Immediately show the "Change to Z Unknown" dialog (blocking until ZDONE)
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext ctx) {
              zunknownDialogContext = ctx; // store context
              return const AlertDialog(
                backgroundColor: Color(0xFF121212),
                title: Text(
                  "Change to Z Unknown",
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                ),
                content: Text(
                  "Measurement starting soon...",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w400),
                ),
              );
            },
          );
        }
        return;
      }

    // ===== When the DUT (Z_unknown) is ready and measurement can proceed =====
    if (receivedText == "ZDONE") {
      print("✅ Z Unknown ready signal received from Arduino");

      // Close the "Change to Z Unknown" dialog if still open
      if (zunknownDialogContext != null) {
        if (mounted) {
          Navigator.of(zunknownDialogContext!, rootNavigator: true).pop();
        }
        zunknownDialogContext = null;
      }
      // continue (don’t return) so data can be parsed if present after ZDONE
      // or return if ZDONE is a pure control message.
      return;
    }

    // ===== End signal for the sweep (you already had this) =====
    if (receivedText == "DONE") {
      print("✅ DONE signal received from Arduino");
      setState(() {
        isStreaming = false;
        _packetBuffer.clear();
      });
      _subscription?.cancel();
      _subscription = null;
      return;
    }

    // Otherwise parse data
    parseGraphData(data, _packetBuffer);
  }
});
    
    // send start command
    List<int> startMessage = [4, 2];
    await sendData(
      characteristic: widget.characteristic,
      data: startMessage,
    );
    
    setState(() {
      isStreaming = true;
    });
    
    print("Single channel data streaming started.");
  }

  void parseGraphData(List<int> rawData, List<int> _packetBuffer) {
    // List<int> _packetBuffer = [];
    _packetBuffer.addAll(rawData);  // append incoming data to buffer
    print("Packet buffer: $_packetBuffer");

    // 8 bytes, 4 bytes for x (int32) and 4 bytes for y (float32)
    while (_packetBuffer.length >= 18) {
      try {
        ByteData impBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(0, 4)));
        double imp  = impBytes.getFloat32(0, Endian.little).toDouble();

        ByteData impRBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(4, 8)));
        double imp_r  = impRBytes.getFloat32(0, Endian.little).toDouble();

        ByteData impIBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(8, 12)));
        double imp_i  = impIBytes.getFloat32(0, Endian.little).toDouble();

        ByteData phaseBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(12, 16)));
        double phase  = phaseBytes.getFloat32(0, Endian.little).toDouble();

        ByteData freqBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(16, 18)));
        int freq = freqBytes.getInt16(0, Endian.little);
        double freq_logged = (log(freq.toDouble())/ln10); // convert to logarithmic scale
        print("📦 Decoded imp: $imp, imp real: $imp_r, imp imag: $imp_i, phase: $phase, freq: $freq");
        
        // adds new point to _dataPoints
        setState(() {
          _impedancePoints.add(FlSpot(imp_r, imp_i));
          _impedanceAbsPoints.add(FlSpot(freq_logged, imp));
          _phasePoints.add(FlSpot(freq_logged, phase));
        });

        // removes the processed 8 bytes
        _packetBuffer.removeRange(0, 18);
      } 
      catch (e) {
        print("❌ Error parsing BLE packet: $e");
        _packetBuffer.clear();
        break;
      }
    }

    // check for leftover "DONE" in buffer
    if (_packetBuffer.length >= 4) {
      String bufferText = String.fromCharCodes(_packetBuffer).trim().toUpperCase();
      if (bufferText == "DONE") {
        print("✅ DONE found in buffer");
        setState(() {
          isStreaming = false;
          _packetBuffer.clear();
        });
        _subscription?.cancel();
        _subscription = null;
      }
    }
  }

  // function to stop data streaming
  void stopDataStream() {
    _subscription?.cancel();
    _subscription = null;
    
    setState(() {
      isStreaming = false;
    });
    
    print("Single channel data streaming stopped.");
  }
  
  @override
  void dispose() {
    // Close any dialogs still open
    if (calibrationDialogContext != null && mounted) {
      Navigator.of(calibrationDialogContext!, rootNavigator: true).pop();
      calibrationDialogContext = null;
    }
    if (zunknownDialogContext != null && mounted) {
      Navigator.of(zunknownDialogContext!, rootNavigator: true).pop();
      zunknownDialogContext = null;
    }

    stopDataStream();
    super.dispose();
  }

  // @override
  // void dispose() {
  //   stopDataStream();
  //   super.dispose();
  // }
  
  @override
  void didUpdateWidget(covariant EISGraphPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.technique != widget.technique) {
      setState(() {
        selectedTechnique = widget.technique;
        print("Updated selectedTechnique: $selectedTechnique");
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // print("Data points count: ${_dataPoints.length}");
    // if (_dataPoints.isNotEmpty) {
    //   print("First point: (${_dataPoints.first.x}, ${_dataPoints.first.y})");
    //   print("Last point: (${_dataPoints.last.x}, ${_dataPoints.last.y})");
    // }
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: buildBackIcon(
          context: context,
          updatePageIndex: widget.updatePageIndex,
          pageKey: 'eisconfig',
          pageIndices: widget.pageIndices,
          writeCharacteristic: _writeCharacteristic,
          bleMessage: [0, 2],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 0.0, right: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 20.0, right: 20.0), // uniform padding on all sides
              child: Text(
              widget.technique,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            ),
            
            
            const SizedBox(height: 5),

            buildLineGraph(
              dataPoints: _impedancePoints, // second dataset
              lineColor: Colors.green,
              xAxisLabel: "Impedance (Re)",
              yAxisLabel: "Impedance (Imag)",
              minX: getMinX(_impedancePoints),
              maxX: getMaxX(_impedancePoints),
              minY: getMinY(_impedancePoints),
              maxY: getMaxY(_impedancePoints),
            ),

            const SizedBox(height: 5),

            buildLineGraph(
              dataPoints: _impedanceAbsPoints, // second dataset
              lineColor: Colors.blue,
              xAxisLabel: "Frequency (Hz)",
              yAxisLabel: "Impedance (Ω)",
              minX: getMinX(_impedanceAbsPoints),
              maxX: getMaxX(_impedanceAbsPoints),
              minY: getMinY(_impedanceAbsPoints),
              maxY: getMaxY(_impedanceAbsPoints),
            ),

            const SizedBox(height: 5),

            buildLineGraph(
              dataPoints: _phasePoints, // second dataset
              lineColor: Colors.red,
              xAxisLabel: "Frequency (Hz)",
              yAxisLabel: "Phase (θ)",
              minX: getMinX(_phasePoints),
              maxX: getMaxX(_phasePoints),
              minY: getMinY(_phasePoints),
              maxY: getMaxY(_phasePoints),
            ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children:[
                 // "Start" Button
                ElevatedButton(
                  onPressed: isStreaming ? stopDataStream : startDataStream,
                  style: ElevatedButton.styleFrom(
                      disabledBackgroundColor: const Color.fromARGB(255, 177, 177, 177),
                      disabledForegroundColor: Colors.white70,
                    ),
                  child: Text(isStreaming ? "Stop" : "Start",
                    style: const TextStyle(
                      color: Color.fromARGB(255, 18, 18, 18),
                      fontSize: 20,
                      fontWeight: FontWeight.w600
                    ),
                  ),
                ),
              ]
            ),
          
          ],
        ),
      ),
    );
  }

Widget buildLineGraph({
  required List<FlSpot> dataPoints,
  required Color lineColor,
  required String xAxisLabel,
  required String yAxisLabel,
  required double minX,
  required double maxX,
  required double minY,
  required double maxY,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      // Y-axis label positioned above the chart
      Padding(
        padding: const EdgeInsets.only(left: 50, bottom: 5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            yAxisLabel,
            style: const TextStyle(
              fontSize: 14,
              color: Color.fromARGB(255, 224, 224, 224),
              fontWeight: FontWeight.normal,
              fontFamily: 'Arial',
            ),
          ),
        ),
      ),
      Container(
        height: 160,
        width: 380,
        child: LineChart(
          LineChartData(
            backgroundColor: Colors.white,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: true,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey.shade300,
                strokeWidth: 0.5,
              ),
              getDrawingVerticalLine: (value) => FlLine(
                color: Colors.grey.shade300,
                strokeWidth: 0.5,
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    if (dataPoints.isEmpty) {
                      // Default axis with no decimals when no data
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color.fromARGB(255, 224, 224, 224),
                            fontWeight: FontWeight.normal,
                            fontFamily: 'Arial',
                          ),
                        ),
                      );
                    }
                    double range = maxX - minX;
                    double margin = range * 0.02;
                    if (value <= minX + margin || value >= maxX - margin) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        value.abs() < 10 
                            ? value.toStringAsFixed(2)   // 2 decimal places
                            : value.toStringAsFixed(0),  // no decimal places
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color.fromARGB(255, 224, 224, 224),
                          fontWeight: FontWeight.normal,
                          fontFamily: 'Arial',
                        ),
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 60, // Increased reserved size for more space
                  getTitlesWidget: (value, meta) {
                    double range = maxY - minY;
                    double margin = range * 0.02;
                    if (value <= minY + margin || value >= maxY - margin) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      width: 55,
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8), // Add space between numbers and graph
                        child: Text(
                          value.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color.fromARGB(255, 224, 224, 224),
                            fontWeight: FontWeight.normal,
                            fontFamily: 'Arial',
                          ),
                        ),
                      ),
                    );
                  },
                ),
                // Remove axisNameWidget completely since we moved it outside
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: Colors.black, width: 1),
            ),
            minX: minX,
            maxX: maxX,
            minY: minY,
            maxY: maxY,
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipBgColor: Colors.black87,
                tooltipRoundedRadius: 8,
                getTooltipItems: (touchedSpots) {
                  return touchedSpots.map((spot) {
                    return LineTooltipItem(
                      'x: ${spot.x.toStringAsFixed(2)}\ny: ${spot.y.toStringAsFixed(2)}',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Arial',
                      ),
                    );
                  }).toList();
                },
              ),
              handleBuiltInTouches: true,
              getTouchedSpotIndicator: (barData, spotIndexes) {
                return spotIndexes.map((index) {
                  return TouchedSpotIndicatorData(
                    FlLine(color: Colors.grey, strokeWidth: 1),
                    FlDotData(show: true),
                  );
                }).toList();
              },
            ),
            lineBarsData: [
              LineChartBarData(
                spots: dataPoints,
                isCurved: false,
                barWidth: 1,                       // <-- hide line
                color: lineColor,                  // used for dots too if no custom painter
                dotData: FlDotData(
                  show: true,                      // <-- show only dots
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3.5,                  // inner dot size
                      color: lineColor,         // fill color
                      strokeWidth: 0.5,           // border thickness
                      strokeColor: Colors.black,  // border color
                    );
                  },
                ),
                belowBarData: BarAreaData(show: false),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 5),
      Padding(
        padding: EdgeInsets.only(left: 55),
        child: Text(
          xAxisLabel,
          style: const TextStyle(
            fontSize: 14,
            color: Color.fromARGB(255, 224, 224, 224),
            fontWeight: FontWeight.normal,
            fontFamily: 'Arial',
          ),
        ),
      ),
    ],
  );
}
}