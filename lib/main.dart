import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final flutterReactiveBle = FlutterReactiveBle();
  final _devices = <DiscoveredDevice>[];
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  DiscoveredDevice? _connectedDevice;
  bool _isScanning = false;
  bool _isConnected = false;
  String _receivedData = "";

  final Uuid serviceUuid = Uuid.parse("4fafc201-1fb5-459e-8fcc-c5c9c331914b");
  final Uuid characteristicUuid = Uuid.parse("beb5483e-36e1-4688-b7f5-ea07361b26a8");

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  Future<void> _scanDevices() async {
    var blePermission = await Permission.bluetoothScan.status;
    if (blePermission.isDenied) {
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
    }

    setState(() {
      _isScanning = true;
    });

    _scanSubscription = flutterReactiveBle.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
      requireLocationServicesEnabled: true,
    ).listen((device) {
      setState(() {
        if (!_devices.any((d) => d.id == device.id)) {
          _devices.add(device);
        }
      });
    });

    // Stop scanning after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      _scanSubscription?.cancel();
      setState(() {
        _isScanning = false;
      });
    });
  }

  void _stopScanning() {
    _scanSubscription?.cancel();
    setState(() {
      _isScanning = false;
    });
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    final connection = flutterReactiveBle.connectToDevice(
      id: device.id,
      servicesWithCharacteristicsToDiscover: {serviceUuid: [characteristicUuid]},
    );

    _connectionSubscription = connection.listen((connectionState) async {
      if (connectionState.connectionState == DeviceConnectionState.connected) {
        setState(() {
          _connectedDevice = device;
          _isConnected = true;
        });
        
        await flutterReactiveBle.requestMtu(deviceId: device.id, mtu: 200);
        
        // Delay 2 seconds before reading data
        await Future.delayed(const Duration(seconds: 1));

        final characteristic = QualifiedCharacteristic(
          serviceId: serviceUuid,
          characteristicId: characteristicUuid,
          deviceId: device.id,
        );

        flutterReactiveBle.subscribeToCharacteristic(characteristic).listen((data) {
          final decodedData = utf8.decode(data);
          print("Received data: $decodedData");
          setState(() {
            _receivedData = decodedData;
          });
        }, onError: (error) {
          print("Error subscribing to characteristic: $error");
        });

        print("Connected to ${device.name}");
      } else if (connectionState.connectionState == DeviceConnectionState.disconnected) {
        setState(() {
          _connectedDevice = null;
          _isConnected = false;
        });
      }
    });
  }

  void _disconnectFromDevice() {
    _connectionSubscription?.cancel();
    setState(() {
      _connectedDevice = null;
      _isConnected = false;
    });
  }

  Future<void> _sendDataToConnectedDevice(List<int> data) async {
    if (_connectedDevice == null) return;

    final characteristic = QualifiedCharacteristic(
      serviceId: serviceUuid,
      characteristicId: characteristicUuid,
      deviceId: _connectedDevice!.id,
    );

    await flutterReactiveBle.writeCharacteristicWithResponse(characteristic, value: data);
  }

  void _sendRequestToEsp32() {
    _sendDataToConnectedDevice(utf8.encode("send"));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE Scanner"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 15),
          Expanded(
            child: ListView.builder(
              itemCount: _devices.length,
              itemBuilder: (context, index) {
                final device = _devices[index];
                return Card(
                  elevation: 2,
                  child: ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.id),
                    trailing: Text('RSSI: ${device.rssi}'),
                    onTap: () => _connectToDevice(device),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 15),
          if (_isConnected)
            Column(
              children: [
                Text('Connected to ${_connectedDevice!.name}'),
                Text('Received data: $_receivedData'),
                ElevatedButton(
                  onPressed: _disconnectFromDevice,
                  child: const Text('Disconnect'),
                ),
                ElevatedButton(
                  onPressed: _sendRequestToEsp32,
                  child: const Text('Send Data'),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            onPressed: _isScanning ? _stopScanning : _scanDevices,
            child: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
          ),
        ],
      ),
    );
  }
}
