import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:typed_data';
import 'package:potentiostat/utils/helper.dart'; 

// Defines widgets for Hardware Configuration Page

class HWConfigPage extends StatefulWidget {
  // function type fields which are passed into the widget from the parent
  final Function(int, [BluetoothDevice?, BluetoothCharacteristic?]) updatePageIndex;
  final Function(String, String) updateHardwareConfig; // need modify
  // final Function(BluetoothCharacteristic) updateCharacteristic;
  final BluetoothDevice? device;
  final BluetoothCharacteristic? characteristic;
  final Map<String, int> pageIndices;
  final String technique;

  const HWConfigPage({
    super.key, 
    required this.updatePageIndex,
    required this.updateHardwareConfig,
    // required this.updateCharacteristic,
    required this.device,
    required this.characteristic,
    required this.pageIndices,
    required this.technique,
  });

  @override
  _HWConfigPageState createState() => _HWConfigPageState();
}

enum RTIAMode { fixed, auto, external}

// Actual state or logic class for HWConfigPage
class _HWConfigPageState extends State<HWConfigPage> {
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothDevice? _connectedDevice;

  RTIAMode? selectedRTIAMode = RTIAMode.fixed; // Default RTIA mode
  String selectedRTIA = "2750"; // Default RTIA value
  String selectedRLOAD = "10"; // Default RLOAD value
  String selectedTechnique = ""; // Default technique
  String externalRTIAValue = ""; // For External RTIA input
  
  bool autoRTIA = false; // Checkbox for Fixed RTIA
  bool externalRTIA = false; // Checkbox for Fixed RTIA

  Map<String, bool> channelConfig = {};
  
  // list for RTIA dropdown options
  final List<String> rtiaOptions = [
      "2750",
      "3500",
      "7000",
      "14000",
      "35000",
      "120000",
      "350000"
  ];

  // list for RLOAD dropdown options
  final List<String> rloadOptions = [
      "10",
      "33",
      "50",
      "100"
  ];

  @override
  void initState() {
    super.initState();
  }
  

  // Pack data for hardware configuration page
  Future<void> packHardwareConfig() async {
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
        widget.updatePageIndex(widget.pageIndices['techconfig']!, widget.device, widget.characteristic);
      }
    });
    
    print("////// DEVICE PASSED FROM PREVIOUS PAGE");
    
    // mode indicator (1) + total bytes(1) + RTIA mode (1) + RTIA value (4) + RLOAD(1)
    // 9 bytes total for hardware configuration
    int totalBytes = 8;
    ByteData byteData = ByteData(totalBytes);

    // Mapping for selection
    final Map<RTIAMode, int> rtiaModeCodes = {
      RTIAMode.fixed: 1,
      RTIAMode.auto: 2,
      RTIAMode.external: 3,      
    };

    // 1st byte: mode indicator (2 for hardware configuration)
    byteData.setUint8(0, 2); // mode indicator for hardware configuration

    // 2nd byte: total bytes in the payload
    byteData.setUint8(1, totalBytes);
    
    // 3rd byte: RTIA mode
    int rtiaModeByte = rtiaModeCodes[selectedRTIAMode!] ?? 1; 
    byteData.setUint8(2, rtiaModeByte);

    // 4th byte: RTIA index (0-6)
    // use uint32 (4 bytes) because RTIA value for external mode can be large
    // if fixed mode, use index of selected RTIA from options
    if (selectedRTIAMode == RTIAMode.fixed) {
      int rtiaIndex = rtiaOptions.indexOf(selectedRTIA);
      byteData.setUint32(3, rtiaIndex, Endian.little); 
    } 
    // external rtia mode, pass value entered by user
    else if (selectedRTIAMode == RTIAMode.external) {
      int rtiaVal = int.tryParse(externalRTIAValue) ?? 0;
      byteData.setUint32(3, rtiaVal, Endian.little);
    } 
    // auto mode, set to 350000 (index 6 + 1)
    else {
      byteData.setUint32(3, 7, Endian.little);  // auto mode, value unused
    }

    // 5th byte: RLOAD index (0-3)
    int rloadIndex = rloadOptions.indexOf(selectedRLOAD);
    byteData.setUint8(7, rloadIndex);

    // convert ByteData to a list of bytes.
    List<int> payload = byteData.buffer.asUint8List();

    // send the byte payload.
    await sendData(
      characteristic: widget.characteristic, // Pass the characteristic
      data: payload,
    );
  }

  // Widget build for Hardware Configuration Page
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
          writeCharacteristic: widget.characteristic,
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

  // Widgets for configuring parameters
  SizedBox configurationParameters(){
  return SizedBox(  // sizedbox to wrap all entry fields and parameters
    child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        // ------------ title ------------
        Text(
          "Hardware Configuration",
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

        // ------------ RTIA dropdown ------------
        const Text("RTIA Mode:"),
         
        ListTile(
          dense: true,
          title: Text("Fixed RTIA", style: Theme.of(context).textTheme.bodySmall),
          leading: Radio<RTIAMode>( // radio buttons for selecting only one RTIA mode
            value: RTIAMode.fixed,
            groupValue: selectedRTIAMode,
            onChanged: (RTIAMode? value) {
              setState(() {
                selectedRTIAMode = value;
              });
            },
          ),
        ),
        ListTile(
          dense: true,
          title: Text("Automatic Current Ranging", style: Theme.of(context).textTheme.bodySmall),
          leading: Radio<RTIAMode>(
            value: RTIAMode.auto,
            groupValue: selectedRTIAMode,
            onChanged: (RTIAMode? value) {
              setState(() {
                selectedRTIAMode = value;
              });
            },
          ),
        ),
        ListTile(
          dense: true,
          title: Text("External RTIA", style: Theme.of(context).textTheme.bodySmall),
          leading: Radio<RTIAMode>(
            value: RTIAMode.external,
            groupValue: selectedRTIAMode,
            onChanged: (RTIAMode? value) {
              setState(() {
                selectedRTIAMode = value;
              });
            },
          ),
        ),
        
        // for conditionally inserting widgets based on selected RTIA mode
        if (selectedRTIAMode == RTIAMode.fixed) ...[
          const Text("RTIA (Ohm):"),
          DropdownButton<String>(
            padding: const EdgeInsets.only(left: 20.0),
            value: selectedRTIA,
            onChanged: (String? newValue) {
              setState(() {
                selectedRTIA = newValue!;
              });
            },
            items: rtiaOptions.map((value) {
              return DropdownMenuItem<String>(
                value: value,
                alignment: Alignment.center,
                child: Text(value, style: Theme.of(context).textTheme.bodySmall),
              );
            }).toList(),
            dropdownColor: const Color.fromARGB(255, 18, 18, 18),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 30),
          ),
        ] 
        else if (selectedRTIAMode == RTIAMode.external) ...[
          const Text("Enter RTIA value (Ohm):"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              style: Theme.of(context).textTheme.bodySmall,
              keyboardType: TextInputType.number,
              onChanged: (value) {
                externalRTIAValue = value;
              },
              decoration: InputDecoration(
                hintText: "e.g., 10000",
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),

        // ------------ RLOAD dropdown ------------
        const Text("RLOAD (Ohm):"),
        DropdownButton<String>(
          padding: const EdgeInsets.only(left: 20.0),
          value: selectedRLOAD,
          onChanged: (String? newValue) {
            setState(() {
              selectedRLOAD = newValue!;
            });
          },
          items: rloadOptions.map<DropdownMenuItem<String>>((String value) {
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

        // ------------ next button ------------
       buildNextButton(
        enabled: true,
        onPressed: () async {
          widget.updateHardwareConfig(selectedRTIA, selectedRLOAD);

          print("RTIA Mode: $selectedRTIAMode");
          print("RTIA Value: $selectedRTIA");
          print("RLOAD: $selectedRLOAD");
          print("Selected Channels: ${channelConfig.entries.where((entry) => entry.value).map((entry) => entry.key).toList()}");
          print("Selected Technique: $selectedTechnique");

          await packHardwareConfig();
          print("Send hardware configuration. Waiting for ACK...");
        },
      ),
    ],
   ),
  );
  
}
}




