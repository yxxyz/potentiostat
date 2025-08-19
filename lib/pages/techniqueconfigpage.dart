import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:potentiostat/utils/helper.dart';
import 'dart:typed_data';

// Defines widgets for technique configuration page

class TechConfigPage extends StatefulWidget {
  final Function(int, [BluetoothDevice?, BluetoothCharacteristic?]) updatePageIndex;
  // final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  final BluetoothCharacteristic? characteristic; 
  final String rtia;
  final String rload;
  final String technique;
  final Map<String, int> pageIndices;

  const TechConfigPage({
    super.key, 
    required this.updatePageIndex,
    // required this.updateCharacteristic,
    required this.device,
    required this.characteristic,
    required this.rtia,
    required this.rload,
    required this.technique,
    required this.pageIndices,
  });

  @override
  _TechConfigPageState createState() => _TechConfigPageState();
  
}

class _TechConfigPageState extends State<TechConfigPage> {
  // pass GATT characteristic and BluetoothDevice from flutter_blue_plus package to variable
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothDevice? _connectedDevice;

  late String selectedTechnique;
  bool _inputComplete = false; // flag to check if all inputs are complete 
  // bool _awaitingACK = false; // Flag to track if we are awaiting ACK
  // bool _isConnected = false;
  // bool _ACKreceived = false;
  // bool _isProcessing = false; // NEW: Prevent multiple processing
  // bool _isPageActive = true; // NEW: Track if page is still active
  
  // technique parameters mapping
  final Map<String, List<String>> techniqueParameters = {
    "CV": ["V Max:", "V Min:", "Scan Rate:", "V Start:", "V End:", "Step Increase:", "Stop Crossing:"],
    "CA": ["Sampling Rate:", "V Start:", "V Step:", "V End:", "T Start:", "T Step:", "T End:", "CA Unit:"],
    "SWV": ["Sampling Rate:", "V Start:", "V End:", "E Step:", "E Pulse:", "Period:", "T Quiet:", "T Relax:"],
    "DPV": ["Sampling Rate:", "V Start:", "V End:", "E Step:", "E Pulse:", "Pwidth:", "Period:", "T Quiet:", "T Relax:"],
    "LSV": ["V Start:", "V End:", "Scan Rate:", "Step Increase:"],
  };

  final Map<String, TextEditingController> _paramControllers = {};

  @override
  void initState() {
    super.initState();
    selectedTechnique = widget.technique;
    _writeCharacteristic = widget.characteristic; 
    _initializeControllers();
    // _ACKreceived = false;
    // _awaitingACK = false;
    // _isProcessing = false;
    // _isPageActive = true;
    
  }  

  // Controller to store and retrieve text for each input field
  void _initializeControllers() {
    _paramControllers.clear();  // ensures old controllers are cleared when technique changes
    List<String>? params = techniqueParameters[selectedTechnique];  // retrieve parameters from technique map
    
    if (params != null) { // proceeds only if parameters are valid
      // creates new controllers for each parameter
      for (String param in params) {
        final controller = TextEditingController();
        controller.addListener(_checkInputField);
        _paramControllers[param] = controller;
      }
    }

    // call function to check if all input fields are filled
    _checkInputField();
  }

  // Checks if all input fields are filled
  void _checkInputField() {
    // checks if all parameters are not empty
    // takes controller as input, '=>' arrow function which trims and check if text is not empty for every controller
    bool allFilled = _paramControllers.values.every((controller) => controller.text.trim().isNotEmpty);

    // only call setState if the completion status of input changes
    if (allFilled != _inputComplete) {  
      setState(() {
        _inputComplete = allFilled;
      });
    }
  }

  // Detect when selected technique changes, reinitialize input fields
  @override
  void didUpdateWidget(covariant TechConfigPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.technique != widget.technique) {
      selectedTechnique = widget.technique;
      _initializeControllers();
    }
  }

  // Dispose of controllers
  @override
  void dispose() {
    _paramControllers.forEach((key, controller) {
      controller.removeListener(_checkInputField);
      controller.dispose();
    });
    super.dispose();
  }

  // Function to gather technique configuration input and send configuration over BLE when Next button pressed
  Future<void> packTechniqueConfig() async {
    _connectedDevice = widget.device;
    _writeCharacteristic = widget.characteristic;

    if (_connectedDevice == null || _writeCharacteristic == null) {
      print("Device or characteristic not found!");

      await connectToDevice(
        device:_connectedDevice!,
        onConnected: () {
          print("✅ Device connected");
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
        // Proceed with navigation
        widget.updatePageIndex(widget.pageIndices['graph']!, widget.device, widget.characteristic);
      }
    });

    // collect parameter values from controllers into a map
    Map<String, int> parameterValues = {};
    _paramControllers.forEach((param, controller) {
      int value = int.tryParse(controller.text) ?? 0; // parse input as integer
      parameterValues[param] = value; // stores value into map
    });
    print("Collected Parameter Values: $parameterValues");

    int numberOfParameters = parameterValues.length;  // get length of parameters
    int payloadLength = 1 + 1 + numberOfParameters*2; // get length of payload
    
    ByteData byteData = ByteData(payloadLength);  // creates new byte data object

    // 1st byte: mode indicator (3 for technique configuration)
    byteData.setUint8(0, 3);

    // 2nd byte: length of payload
    byteData.setUint8(1, payloadLength);

    // 3rd byte onwards: parameter values
    // each parameter value is stored as a 2-byte integer (-32768 to 32767)
    int offset = 2;
    parameterValues.forEach((param, value) {
      byteData.setInt16(offset, value, Endian.little);
      offset += 2;
    });

    // converts entire buffer into uint8 list
    List<int> payload = byteData.buffer.asUint8List();
    print("Payload to send: $payload");

    // send the byte payload.
    await sendData(
      characteristic: widget.characteristic, // Pass the characteristic
      data: payload,
    );


  }

  // Function to build an input field with its associated controller
  Widget _buildInputField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        children: [
          SizedBox(
            width: 150,
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
              onChanged: (_) => _checkInputField(), // checks input field with every keystroke
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
                fillColor: Colors.transparent,
              ),
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  } 

  @override
  Widget build(BuildContext context) {
    print("✅ Received Hardware Config in TechConfigPage:");
    print("RTIA: ${widget.rtia}");
    print("RLOAD: ${widget.rload}");
    print("Technique Config: ${widget.technique}");
    
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: buildBackIcon(
          context: context,
          updatePageIndex: widget.updatePageIndex,
          pageKey: 'hwconfig',
          pageIndices: widget.pageIndices,
          writeCharacteristic: _writeCharacteristic,
          bleMessage: [0, 2],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(), 
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ------------ title ------------
              Text(
                "Technique Configuration",
                style: Theme.of(context).textTheme.bodyLarge,
              ),

              const SizedBox(height: 10),

              // ------------ divider ------------
              Divider(
                color: Colors.grey.shade200,
                thickness: 1, 
                height: 10,
              ),

              const SizedBox(height: 20),

              // ------------ parameters ------------
              Text(
                widget.technique,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const SizedBox(height: 20),

              // dynamically display technique parameters based on selected technique
              if (techniqueParameters[selectedTechnique] != null)
                ...techniqueParameters[selectedTechnique]!.map((param) {
                  return _buildInputField(param, _paramControllers[param]!);
                }).toList()
              else
                Text("No parameters defined for $selectedTechnique",
                    style: Theme.of(context).textTheme.bodySmall),
              
              const SizedBox(height: 30),
              
              // NEW: Updated button with processing state
              buildNextButton(
                enabled: _inputComplete,
                onPressed: () async {
                  print("🔘 Next button pressed");
                  await packTechniqueConfig();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}