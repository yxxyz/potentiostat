import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'pages/homepage.dart';
import 'pages/blepage.dart';
import 'pages/modeconfigpage.dart';
import 'pages/hardwareconfigpage.dart';
import 'pages/eisconfigpage.dart';
import 'pages/techniqueconfigpage.dart';
import 'pages/graphpage.dart';
import 'pages/eisgraphpage.dart';

void main(){
  runApp(const InitApp());
}

class InitApp extends StatelessWidget{
   const InitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Poppins',
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 224, 224, 224)),
          bodyMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color.fromARGB(255, 224, 224, 224)),
          bodySmall: TextStyle(fontSize: 16, color: Color.fromARGB(255, 224, 224, 224)),
        )
        ),
      home: MainApp(),
    );
  }
}

class MainApp extends StatefulWidget{
  const MainApp({super.key});

  @override
  State<MainApp> createState() => MainAppState();
}


class MainAppState extends State<MainApp> {
  int _selectedIndex = 0;
  String _RTIA = "0";
  // bool _fixedRTIA = false;
  String _RLOAD = "0";
  String _technique = "Cyclic Voltammetry";
  bool _calibrationEnabled = false;

  final Map<String, int> pageIndices = {
    'home': 0,
    'ble': 1,
    'modeconfig': 2,
    'hwconfig': 3,
    'eisconfig': 4,
    'techconfig': 5,
    'graph': 6,
    'eisgraph': 7,
  };

  BluetoothDevice? _selectedDevice;
  BluetoothCharacteristic? _BLEcharacteristic;

  void updatePageIndex(int index, [BluetoothDevice? device, BluetoothCharacteristic? characteristic]){
    setState(() {
      _selectedIndex = index;
      if (device != null){
        _selectedDevice = device;
      }
      if (characteristic != null) {
      _BLEcharacteristic = characteristic;
    }
    });
  }

  void updateModeConfig(String selectedTechnique){
    setState((){
      _technique = selectedTechnique;
    });
  }

  void updateHardwareConfig(String selectedRTIA, String selectedRLOAD){
    setState((){
      _RTIA = selectedRTIA;
      // _fixedRTIA = fixedRTIA;
      _RLOAD = selectedRLOAD;
    });
  }

  void updateCharacteristic(BluetoothCharacteristic characteristic) {
  setState(() {
    _BLEcharacteristic = characteristic;
  });
  }

  void updateCalibrationState(bool calibrationEnabled) {
  setState(() {
    _calibrationEnabled = calibrationEnabled;
  });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
    HomePage(
      updatePageIndex: updatePageIndex,
      pageIndices: pageIndices,
    ),
    BlePage(
      updatePageIndex: updatePageIndex,
      // updateCharacteristic: updateCharacteristic,
      pageIndices: pageIndices,
    ),
    ModeConfigPage(
      updatePageIndex: updatePageIndex,
      updateModeConfig: updateModeConfig,
      updateCharacteristic: updateCharacteristic,
      device: _selectedDevice,
      characteristic: _BLEcharacteristic,
      pageIndices: pageIndices,
    ),
    HWConfigPage(
      updatePageIndex: updatePageIndex,
      updateHardwareConfig: updateHardwareConfig,
      // updateCharacteristic: updateCharacteristic,
      device: _selectedDevice,
      characteristic: _BLEcharacteristic,
      pageIndices: pageIndices,
      technique: _technique,
    ),
    EISConfigPage(
      updatePageIndex: updatePageIndex,
      updateCalibrationState: updateCalibrationState,
      // updateCharacteristic: updateCharacteristic,
      device: _selectedDevice,
      characteristic: _BLEcharacteristic,
      technique: _technique,
      pageIndices: pageIndices,
    ),
    TechConfigPage(
      updatePageIndex: updatePageIndex,

      device: _selectedDevice,
      characteristic: _BLEcharacteristic,
      rtia: _RTIA,
      // fixedRtia: _fixedRTIA,
      rload: _RLOAD,
      technique: _technique,
      pageIndices: pageIndices,
    ),
    GraphPage(
      updatePageIndex: updatePageIndex,
      updateCharacteristic: updateCharacteristic,
      device: _selectedDevice,
      characteristic: _BLEcharacteristic,
      rtia: _RTIA,
      // fixedRtia: _fixedRTIA,
      rload: _RLOAD,
      technique: _technique,
      pageIndices: pageIndices,
    ),
    EISGraphPage(
      updatePageIndex: updatePageIndex,
      device: _selectedDevice,
      characteristic: _BLEcharacteristic,
      technique: _technique,
      calibrationEnabled: _calibrationEnabled,
      pageIndices: pageIndices,
    )
  ];
    return IndexedStack(
      index: _selectedIndex,
      children: _pages,
    );
  }
}


