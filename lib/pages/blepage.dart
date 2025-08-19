import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';

// Defines widgets for BLE Page

class BlePage extends StatefulWidget {
  final Function(int, [BluetoothDevice?, BluetoothCharacteristic?] ) updatePageIndex;
  // final Function(BluetoothCharacteristic) updateCharacteristic;
  final Map<String, int> pageIndices;

  const BlePage({
    super.key, 
    required this.updatePageIndex,
    // required this.updateCharacteristic,
    required this.pageIndices,
  });

  @override
  _BlePageState createState() => _BlePageState();
}

// Actual state or logic class for BlePage
class _BlePageState extends State<BlePage> {
  List<ScanResult> _scanResults = [];
  // BluetoothDevice? _connectedDevice;
  bool _isScanning = false;

  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    listenToBluetoothState(); // ensures Bluetooth state is monitored
  }
  
  // Function for requesting permissions
  Future<bool> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  // Function for scanning bluetooth devices
  Future<void> scanDevices() async {
    // request necessary permissions
    if (!await _requestPermissions()) return;

    // check if bluetooth is enabled on mobile device
    BluetoothAdapterState btState = await FlutterBluePlus.adapterState.first;
    if (btState != BluetoothAdapterState.on) {
      print("Bluetooth is off. Please enable it.");
       _showErrorDialog("Bluetooth is OFF", "Please enable Bluetooth to scan for devices.");
      return;
    }

    // check if location services are enabled on mobile device
    bool locationEnabled = await Geolocator.isLocationServiceEnabled();
    if (!locationEnabled) {
      _showErrorDialog("Location Services are OFF", "Please enable location services to scan for devices.");
      return;
    }

    // used for changing states which might affect the UI
    setState(() {
      _isScanning = true;
      _scanResults = [];
    });

    // start scanning
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // collect scan results
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (!_scanResults.any((existing) => existing.device.remoteId == result.device.remoteId)) {
          // add the scan results for display on app
          setState(() {
            _scanResults.add(result);
          });
          print("Found device: ${result.advertisementData.advName} (${result.device.remoteId})");
        }
      }
    });

    // stop scanning after timeout
    Future.delayed(const Duration(seconds: 10), () async {
      // check if widget is still part of widget tree before running setState
      // prevent crashes if the widget is disposed before the timeout
      if (mounted) {
        await FlutterBluePlus.stopScan();
        setState(() {
          _isScanning = false;
        });
      }
    });
  }

  // Function for connecting to device when "connect" button is pressed
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      print("connecting to device");

      // wait for timeout 10s 
      await device.connect(timeout: const Duration(seconds: 5));

      device.connectionState.listen((state) async {
        if (state == BluetoothConnectionState.connected) {
          FlutterBluePlus.stopScan();
          discoverServices(device);

          setState(() {
            _connectedDevice = device;
            widget.updatePageIndex(widget.pageIndices['modeconfig']!, device, _writeCharacteristic);
          });
        } 
        else if (state == BluetoothConnectionState.disconnected) {
          print("Disconnected from ${device.platformName}");
        }
      });
    } 
    catch (e) {
      print("Connection failed: $e");
    }
  }

  Future<void> discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();

     for (BluetoothService service in services) {
      print("Service UUID: ${service.uuid}");
      for (BluetoothCharacteristic characteristic in service.characteristics) {
        print("Characteristic UUID: ${characteristic.uuid}");
        if (service.uuid.toString().toLowerCase().contains("ffe0") &&
            characteristic.uuid.toString().toLowerCase().contains("ffe1")) {
          setState(() {
            _writeCharacteristic = characteristic;
          });
          print("HM10 characteristic found: ${characteristic.uuid}");

          // wait for ACK
          await enableNotifications(
            characteristic: characteristic,
            // onACKReceived: (char) {
            //   widget.updatePageIndex(widget.pageIndices['modeconfig']!, device, _writeCharacteristic);
            // },
          );
        }
      }
    }
  } 

  Future<void> enableNotifications({
    required BluetoothCharacteristic characteristic,
  }) async {
    try {
      // Enable notifications for the characteristic
      await characteristic.setNotifyValue(true);

      print("✅ Notifications enabled for characteristic: ${characteristic.uuid}");
    } catch (e) {
      print("⚠️ Error enabling notifications: $e");
    }
  }

  // Function to start listening to Bluetooth state changes once UI is built
  void listenToBluetoothState() {
    FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.off) {
        print("Bluetooth is OFF! Please enable it.");
        // Optionally, show an alert dialog to the user.
      } else if (state == BluetoothAdapterState.on) {
        print("Bluetooth is ON!");
      }
    });
  }

  void _showErrorDialog(String title, String message){
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            child: const Text("OK", style: TextStyle(color: Colors.white)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _connectedDevice?.disconnect(); // only call disconnect if _connectedDevice is not null
    super.dispose();
  }

  // Widget build for rendering UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color.fromARGB(255, 18, 18, 18),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: backIcon(context, widget.updatePageIndex, 'home'),
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: _isScanning ? null : scanDevices,
            style: ElevatedButton.styleFrom(
              foregroundColor: Color.fromARGB(255, 236, 236, 241),
              backgroundColor: Color.fromARGB(255, 236, 236, 241),
              disabledBackgroundColor: Color.fromARGB(255, 103, 103, 103),
              disabledForegroundColor: const Color.fromARGB(179, 237, 237, 237),
            ),
            child: Text(_isScanning ? "Scanning..." : "Scan for Devices",
              style: const TextStyle(
                color: Color.fromARGB(255, 18, 18, 18),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _scanResults.length,
              itemBuilder: (context, index) {
                final result = _scanResults[index];
                return ListTile(
                  title: Text(
                    result.device.platformName.isNotEmpty
                        ? result.device.platformName
                        : "Unknown Device",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  subtitle: Text(
                    result.device.remoteId.toString(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => connectToDevice(result.device),
                    child: const Text(
                      "Connect",
                      style: TextStyle(
                        color: Color.fromARGB(255, 18, 18, 18),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget backIcon(BuildContext context, Function(int) updatePageIndex, String pageKey) {
    return Container(
      color: Colors.transparent,
      child: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Color.fromARGB(255, 236, 236, 241)),
        onPressed: (){
          final targetIndex = widget.pageIndices[pageKey];
          if (targetIndex != null) {
            updatePageIndex(targetIndex);
          }
        }
      ),
    );
  }
}


