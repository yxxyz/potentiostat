import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:potentiostat/utils/helper.dart'; 
import 'dart:typed_data';

class EISConfigPage extends StatefulWidget {
  final Function(int, [BluetoothDevice?, BluetoothCharacteristic?]) updatePageIndex;
  final Function(bool) updateCalibrationState;
  // final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  final BluetoothCharacteristic? characteristic; 
  final String technique;
  final Map<String, int> pageIndices;

  const EISConfigPage({
    super.key, 
    required this.updatePageIndex,
    required this.updateCalibrationState,
    // required this.updateCharacteristic,
    required this.device,
    required this.characteristic,
    required this.technique,
    required this.pageIndices,
  });

  @override
  _EISConfigPageState createState() => _EISConfigPageState();
}

class _EISConfigPageState extends State<EISConfigPage> {
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothDevice? _connectedDevice;
  bool _isChecked = false; // for calibration checkbox
  bool calibration = false;
  bool _awaitingACK = false; // Flag to track if ACK is expected
  bool _isConnected = false;
  String selectedVexcitation = "2 Vpp";
  String selectedPGAgain = "1";
  String selectedMux = "150";
  String startFreq = "";
  String endFreq = "";
  String numPoints = "";

  final List<String> Vexcitation = [
    "2 Vpp",
    "1 Vpp",
    "0.4 Vpp",
    "0.2 Vpp"
  ];

  final List<String> PGAgain = [
    "1",
    "5"
  ];

  final List<String> Mux = [
    "150",
    "330",
    "1500",
    "3300",
    "ext 1",
    "ext 2",
    "ext 3",
    "ext 4"
  ];

  final TextEditingController startFreqController = TextEditingController();
  final TextEditingController endFreqController = TextEditingController();
  final TextEditingController numPointsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // selectedTechnique = widget.technique;

    // _isChecked defaults to false → set defaults + lock fields
    if (!_isChecked) {
      startFreqController.text = '10';
      endFreqController.text = '10000';
      numPointsController.text = '30';
    }
  }

  @override
  void dispose() {
    startFreqController.dispose();
    endFreqController.dispose();
    numPointsController.dispose();
    super.dispose();
  }

  Future<void> packEISConfig() async {
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
        widget.updatePageIndex(widget.pageIndices['eisgraph']!, _connectedDevice, _writeCharacteristic);
        widget.updateCalibrationState(calibration);
      }
    });

    // Capture input values
    startFreq = startFreqController.text.trim();
    endFreq = endFreqController.text.trim();
    numPoints = numPointsController.text.trim();
    calibration = _isChecked;

    // You can print or pass them here
    print("EIS CONFIG:");
    print("Start Frequency: $startFreq");
    print("End Frequency: $endFreq");
    print("Num Points: $numPoints");
    print("Excitation: $selectedVexcitation");
    print("Calibration: $calibration");

    int totalBytes = 12;
    ByteData byteData = ByteData(totalBytes);

    // Mode 2 for hardware configuration
    byteData.setUint8(0, 2);
    byteData.setUint8(1, totalBytes); 

    if(calibration) {
      byteData.setUint8(2, 1); // Calibration enabled
    } 
    else {
      byteData.setUint8(2, 0); // Calibration disabled
    }

    byteData.setUint8(3, Vexcitation.indexOf(selectedVexcitation));
    byteData.setUint8(4, PGAgain.indexOf(selectedPGAgain));
    byteData.setUint8(5, Mux.indexOf(selectedMux));
    byteData.setUint16(6, int.parse(startFreq), Endian.little);
    byteData.setUint16(8, int.parse(endFreq), Endian.little);
    byteData.setUint16(10, int.parse(numPoints), Endian.little);

    print("MUX VALUE: ${Mux.indexOf(selectedMux)}");
    print("START FREQ VALUE: ${int.parse(startFreq)}");
    print("END FREQ VALUE: ${int.parse(endFreq)}");
    
    List<int> payload = byteData.buffer.asUint8List();

    await sendData(
      characteristic: _writeCharacteristic, // Pass the characteristic
      data: payload,
    );
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
          pageKey: 'modeconfig',
          pageIndices: widget.pageIndices,
          writeCharacteristic: _writeCharacteristic,
          bleMessage: [0, 2],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView( // allows scrolling and prevent pixel overflow when keyboard active
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: ConstrainedBox(  // ensures scroll view expands to full screen height
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: IntrinsicHeight( // force column to size height based on children
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  configurationParameters(),
                  const Spacer(),  // pushes button to bottom if space available
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {required bool enabled}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(
            width: 120,
            height: 40,
            child: TextField(
              controller: controller,
              // onChanged: (_) => _checkInputField(), // checks input field with every keystroke
              enabled: enabled,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 1,
              cursorColor: Colors.grey.shade200,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 5.0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(5),
                  borderSide: BorderSide(color: Colors.grey.shade200, width: 2.0),
                ),
                filled: true,
                fillColor: enabled ? Colors.transparent : Colors.black12, // subtle disabled look
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  } 

  Widget configurationParameters() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "EIS Configuration",
          style: Theme.of(context).textTheme.bodyLarge,
        ),

        const SizedBox(height: 10),

        // ------------ divider line ------------
        Divider(
          color: Colors.grey.shade200,
          thickness: 1, // Line thickness
          height: 10, // Space around the divider
        ),

        const SizedBox(height: 20),

        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Calibration', 
            style: Theme.of(context).textTheme.bodyMedium
          ),
          value: _isChecked,
          onChanged: (bool? newValue) {
            setState(() {
              _isChecked = newValue ?? false;

              if (!_isChecked) {
                // Calibration OFF → set defaults & lock fields
                startFreqController.text = '10';
                endFreqController.text = '10000';
                numPointsController.text = '30';
              } else {
                startFreqController.clear();
                endFreqController.clear();
                numPointsController.clear();
              }
            });
          },
          side: const BorderSide(
            color: Colors.white, // border color
            width: 2.0,
          ),
          activeColor: Colors.grey.shade700,
        ),

        const SizedBox(height: 20),

        const Text("Excitation Voltage Amplitude:"),
        DropdownButton<String>(
          padding: const EdgeInsets.only(left: 20.0),
          value: selectedVexcitation,
          onChanged: (String? newValue) {
            setState(() {
              selectedVexcitation = newValue!;
            });
          },
          items: Vexcitation.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              alignment: Alignment.center, 
              child: Text(value, style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
          dropdownColor: Color.fromARGB(255, 18, 18, 18),
          icon: const Icon( 
                  Icons.arrow_drop_down,
                  color: Colors.white, 
                  size: 30, 
                ),
        ),

        const SizedBox(height: 20),

        const Text("PGA Gain:"),
        DropdownButton<String>(
          padding: const EdgeInsets.only(left: 20.0),
          value: selectedPGAgain,
          onChanged: (String? newValue) {
            setState(() {
              selectedPGAgain = newValue!;
            });
          },
          items: PGAgain.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              alignment: Alignment.center, 
              child: Text(value, style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
          dropdownColor: Color.fromARGB(255, 18, 18, 18),
          icon: const Icon( 
                  Icons.arrow_drop_down,
                  color: Colors.white, 
                  size: 30, 
                ),
        ),

        const SizedBox(height: 20),

        const Text("Mux:"),
        DropdownButton<String>(
          padding: const EdgeInsets.only(left: 20.0),
          value: selectedMux,
          onChanged: (String? newValue) {
            setState(() {
              selectedMux = newValue!;
            });
          },
          items: Mux.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              alignment: Alignment.center, 
              child: Text(value, style: Theme.of(context).textTheme.bodySmall),
            );
          }).toList(),
          dropdownColor: Color.fromARGB(255, 18, 18, 18),
          icon: const Icon( 
            Icons.arrow_drop_down,
            color: Colors.white, 
            size: 30, 
          ),
        ),

        const SizedBox(height: 20),

        _buildInputField("Start Frequency (Hz):", startFreqController, enabled: _isChecked),
        _buildInputField("End Frequency (Hz):", endFreqController, enabled: _isChecked),
        _buildInputField("Number of Points:", numPointsController, enabled: _isChecked),

        const SizedBox(height: 20),

        

        // ------------ next button ------------
        buildNextButton(
          enabled: true,
          onPressed: () async {
            _connectedDevice = widget.device;

            packEISConfig();
            print("Send hardware configuration. Waiting for ACK...");
          },
        ),

        const SizedBox(height: 35),
      ],
    );
  }
}
