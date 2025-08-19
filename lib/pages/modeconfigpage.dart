import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:potentiostat/utils/helper.dart'; 
import 'dart:typed_data';


class ModeConfigPage extends StatefulWidget {
  final Function(int, [BluetoothDevice?, BluetoothCharacteristic?]) updatePageIndex;
  final Function(String) updateModeConfig;
  final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  final BluetoothCharacteristic? characteristic;
  final Map<String, int> pageIndices;

  const ModeConfigPage({
    super.key, 
    required this.updatePageIndex,
    required this.updateModeConfig,
    required this.updateCharacteristic,
    required this.device,
    required this.characteristic,
    required this.pageIndices,
  });

  @override
  _ModeConfigPageState createState() => _ModeConfigPageState();
}


class _ModeConfigPageState extends State<ModeConfigPage> {
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothDevice? _connectedDevice;

  bool _isConnected = false;
  bool _awaitingACK = false; // Flag to track if we are awaiting ACK
  bool _ackListenerAttached = false;

  String? selectedTechnique;

  @override
  void initState() {
    super.initState();
    selectedTechnique = null; 
  }

  Future<void> sendTechnique(techniqueKey) async {
    _connectedDevice = widget.device;
    _writeCharacteristic = widget.characteristic;

    if(_connectedDevice == null || _writeCharacteristic == null) {
      print("Device or characteristic not found!");

      await connectToDevice(
        device: _connectedDevice!,
        onConnected: () {
          setState(() {
            print("✅ Device connected in mode config page");
          });
        },
        discoverServices: (device) async {
          await discoverServices(
            device: device,
            onCharacteristicFound: (characteristic) {
              setState(() {
                _writeCharacteristic = characteristic;
              });
            },
          );
        },
      );
    }
    
    _writeCharacteristic!.lastValueStream.listen((value) {
      String received = String.fromCharCodes(value);
      print("Received: $received");

      if (received.trim() == "ACK") {
        if (techniqueKey == 'EIS') {
            widget.updatePageIndex(widget.pageIndices['eisconfig']!, _connectedDevice, _writeCharacteristic);
            print('Navigating to EIS Config Page');
          } 
          else {
            widget.updatePageIndex(widget.pageIndices['hwconfig']!, _connectedDevice, _writeCharacteristic);
            print('Navigating to HW Config Page for $techniqueKey');
          }
        }
    });
  
    
    setState(() {
      selectedTechnique = techniqueKey;
    });

    widget.updateModeConfig(selectedTechnique!);

    print('Selected Technique: $selectedTechnique');

    Map<String, int> techniqueIndices = {
      'CV': 1,
      'CA': 2,
      'SWV': 3,
      'DPV': 4,
      'LSV': 5,
      'EIS': 6,
    };

    // Get index and send over BLE
    int indexToSend = techniqueIndices[selectedTechnique!]!;
    
    int totalBytes = 3;
    ByteData byteData = ByteData(totalBytes);

    byteData.setUint8(0, 1);
    byteData.setUint8(1, totalBytes);
    byteData.setUint8(2, indexToSend); 
    
    List<int> payload = byteData.buffer.asUint8List();
    if (_writeCharacteristic != null) {
      await sendData(
        characteristic: _writeCharacteristic,
        data: payload, // e.g., command ID 0, then index
      );
      print("data sent: $payload");
    } 
    else {
      print("⚠️ Write characteristic is null!");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: buildBackIcon(
          context: context,
          updatePageIndex: widget.updatePageIndex,
          pageKey: 'ble',
          pageIndices: widget.pageIndices,
          writeCharacteristic: _writeCharacteristic,
          bleMessage: [0, 2],
        ),
      ),
     body: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start, // ensures left alignment
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            'Mode Configuration',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
       
        SizedBox(height: 80), // spacing below the title

        // Wrap button grid in Center to keep it centered
        Center(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  buildImageLabelButton('assets/cv.png', 'Cyclic\n Voltammetry', 'CV'),
                  buildImageLabelButton('assets/ca.png', 'Chronoamperometry', 'CA'),
                ],
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  buildImageLabelButton('assets/swv.png', 'Square Wave\n Voltammetry', 'SWV'),
                  buildImageLabelButton('assets/dpv.png', 'Differential Pulse\n Voltammetry', 'DPV'),
                ],
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  buildImageLabelButton('assets/lsv.png', 'Linear Sweep\n Voltammetry', 'LSV'),
                  buildImageLabelButton('assets/eis.png', 'Electrochemical\n Impedance\n Spectroscopy', 'EIS'),
                ],
              ),
            ],
          ),
        ),
      ],
    ),

    );
  }

  Widget buildImageLabelButton(String imagePath, String label, String techniqueKey) {
    return GestureDetector(
       onTap: () async {
        sendTechnique(techniqueKey);
        
      },
      child: Container(
        width: 180,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(
            color: Colors.white,
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center( // ✅ Center the Column inside the container
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center, // ✅ Vertically center
            crossAxisAlignment: CrossAxisAlignment.center, // ✅ Horizontally center
            children: [
              Image.asset(
                imagePath,
                width: 48,
                height: 48,
              ),
              SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color.fromRGBO(224, 224, 224, 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
