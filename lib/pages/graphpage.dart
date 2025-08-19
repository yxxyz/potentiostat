import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:potentiostat/utils/helper.dart';
import 'dart:async';
import 'dart:typed_data';

// widget class
class GraphPage extends StatefulWidget {
  final Function(int, [BluetoothDevice?]) updatePageIndex;
  final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  final BluetoothCharacteristic? characteristic; 
  final String rtia;
  final String rload;
  final String technique;
  final Map<String, int> pageIndices;

  const GraphPage({
    super.key, 
    required this.updatePageIndex,
    required this.updateCharacteristic,
    required this.device,
    required this.characteristic,
    required this.rtia,
    required this.rload,
    required this.technique,
    required this.pageIndices,
  });

  @override
  _GraphPageState createState() => _GraphPageState(); 
}

class _GraphPageState extends State<GraphPage> {
  late String selectedTechnique; 
  bool isStreaming = false;
  StreamSubscription<List<int>>? _subscription;
  
  // stores elements of type FlSpot (x, y) for graph data points
  List<FlSpot> _dataPoints = [];
  
  // single color for the line
  final Color _lineColor = Colors.blue;
  
  // Get min/max values for data points
  double get minX {
    if (_dataPoints.isEmpty) {
      return -500;  // if empty return -500 as minimum x value
    }
    // return minimum x - 50 with a margin of 50
    return _dataPoints.map((spot) => spot.x).reduce((a, b) => a < b ? a : b) - 50;
  }

  double get maxX {
    if (_dataPoints.isEmpty) {
      return 500; // if empty return 500 as maximum x value
    }
    // return minimum x + 50 with a margin of 50
    return _dataPoints.map((spot) => spot.x).reduce((a, b) => a > b ? a : b) + 50;
  }

  double get minY {
    if (_dataPoints.isEmpty) {
      return -50; // if empty return -50 as minimum y value
    }
    // return minimum y * 1.2 with a margin of 20%
    return _dataPoints.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) * 1.2;
  }

  double get maxY {
    if (_dataPoints.isEmpty) {
      return 50;  // if empty return 50 as maximum y value
    }
    // return maximum y * 1.2 with a margin of 20%
    return _dataPoints.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) * 1.2;
  }

  // get x-axis labels based on selected technique
  String get xAxisLabel {
    switch (selectedTechnique) {
      case 'CA':
        return 'Time (ms)';      
      case 'CV':
      case 'LSV':
      case 'DPV':
      case 'SWV':
        return 'Voltage (mV)';
      default:
        return 'X-Axis';
    }
  }

  // get y-axis labels based on selected technique
  String get yAxisLabel {
    switch (selectedTechnique) {
      case 'CA':
      case 'CV':
      case 'LSV':
        return 'Current (µA)';
      case 'DPV':
      case 'SWV':
        return 'Differential Current (µA)';
      default:
        return 'Y-Axis';
    }
  }

  @override
  void initState() {
    super.initState();
    selectedTechnique = widget.technique;
  }  

  Future<void> startDataStream() async {
    if (widget.characteristic == null) {
      print("⚠️ No characteristic found for listening!");
      return;
    }
    
    // cancel any existing subscription first
    _subscription?.cancel();
    
    // clear existing data points
    setState(() {
      _dataPoints.clear();
    });
    
    // enable notifications
    await enableNotifications(
      characteristic: widget.characteristic!,
      onACKReceived: (char) {
        print("✅ ACK received in GraphPage!");
      },
    );
    
    List<int> _packetBuffer = [];
    
    void parseGraphData(List<int> rawData) {
      _packetBuffer.addAll(rawData);  // append incoming data to buffer
      print("Packet buffer: $_packetBuffer");

      // 8 bytes, 4 bytes for x (int32) and 4 bytes for y (float32)
      while (_packetBuffer.length >= 8) {
        try {
          ByteData xBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(0, 4)));
          double x = xBytes.getInt32(0, Endian.little).toDouble();

          ByteData yBytes = ByteData.sublistView(Uint8List.fromList(_packetBuffer.sublist(4, 8)));
          double y = yBytes.getFloat32(0, Endian.little);
          
          print("📦 Decoded X: $x, Y: $y");
          
          // adds new point to _dataPoints
          setState(() {
            _dataPoints.add(FlSpot(x, y));
          });

          // removes the processed 8 bytes
          _packetBuffer.removeRange(0, 8);
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
    
    // subscribe to ble stream, functino is triggered when new BLE data is sent
    _subscription = widget.characteristic!.onValueReceived.listen((List<int> data) {
      if (data.isNotEmpty) {
        print("Raw data received: $data");
        String receivedText = String.fromCharCodes(data).trim().toUpperCase();
        print("Parsed text: '$receivedText'");

        // check for "DONE" first
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

        // if not "DONE", treat as data packet
        parseGraphData(data);
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
    stopDataStream();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(covariant GraphPage oldWidget) {
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
    print("Data points count: ${_dataPoints.length}");
    if (_dataPoints.isNotEmpty) {
      print("First point: (${_dataPoints.first.x}, ${_dataPoints.first.y})");
      print("Last point: (${_dataPoints.last.x}, ${_dataPoints.last.y})");
    }
    
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: backIcon(context, widget.updatePageIndex, 'techconfig'),
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 20.0, right: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.technique,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            
            const SizedBox(height: 20),

            // Graph
            Container(
              height: 500,
              child: LineChart(
                // setup of graph area
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
                    
                    // plot axes value for x axis
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          // Skip titles near minX and maxX to avoid overlap
                          double range = maxX - minX;
                          double margin = range * 0.02;
                          if (value <= minX + margin || value >= maxX - margin) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(fontSize: 14, color: Color.fromARGB(255, 224, 224, 224), fontWeight: FontWeight.normal, fontFamily: 'Arial'),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // plot axes value for y axis
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          double range = maxY - minY;
                          double margin = range * 0.02;

                          if (value <= minY + margin || value >= maxY - margin) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(left:5),
                            child: Text(
                              value.toInt().toString(),
                              style: const TextStyle(fontSize: 14, color: Color.fromARGB(255, 224, 224, 224), fontWeight: FontWeight.normal,fontFamily: 'Arial'),
                            ),
                          );
                        },
                      ),
                      axisNameWidget: Padding(
                        padding: EdgeInsets.only(left: 2, right: 2),
                        child: Text(
                          yAxisLabel,
                          style: TextStyle(fontSize: 15, color: Color.fromARGB(255, 224, 224, 224), fontWeight: FontWeight.normal, fontFamily: 'Arial'),
                        ),
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  
                  // border for graph
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  
                  // label to show x and y value when touching graph
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: Colors.black87,
                      tooltipRoundedRadius: 8,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          return LineTooltipItem(
                            'x: ${touchedSpot.x.toStringAsFixed(2)}\ny: ${touchedSpot.y.toStringAsFixed(2)}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
                      spots: _dataPoints,
                      isCurved: false,
                      barWidth: 2,
                      color: _lineColor,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                )
              ),
            ),

            const SizedBox(height: 10),

            // label for x axis
            Center(
              child: Text(
                xAxisLabel,
                style: TextStyle(fontSize: 15, color: Color.fromARGB(255, 224, 224, 224), fontWeight: FontWeight.normal,fontFamily: 'Arial'),
              ),
            ),
            
            const SizedBox(height: 10),
            
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

            const SizedBox(height: 20),
          
          ],
        ),
      ),
    );
  }
  
  // Back Button Widget
  Widget backIcon(BuildContext context, Function(int) updatePageIndex, String pageKey) {
    return Container(
      color: Colors.transparent,
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color.fromARGB(255, 224, 224, 224)),
        onPressed: () async {
          print("Back button pressed. Sending '0' to Arduino...");
          List<int> backMessage = [0, 2];
          await sendData(
            characteristic: widget.characteristic,
            data: backMessage,
          );
          setState(() {
            _dataPoints.clear();
          });
          final targetIndex = widget.pageIndices[pageKey];
          if (targetIndex != null) {
            updatePageIndex(targetIndex);
          }
        },
      ),
    );
  }
}