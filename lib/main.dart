import 'package:bluetooth_flut_blue/sensor_chart_page.dart';
import 'package:bluetooth_flut_blue/sensor_data_page.dart';
import 'package:bluetooth_flut_blue/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ble_controller.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE Scanner"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.data_usage),
            onPressed: () {
              Get.to(() => SensorDataPage());
            },
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              Get.to(() => ChartPage());
            },
          ),
        ],
      ),
      body: GetX<BleController>(
        init: BleController(),
        builder: (controller) {
          return Column(
            children: [
              const SizedBox(height: 15),
              Expanded(
                child: ListView.builder(
                  itemCount: controller.devices.length,
                  itemBuilder: (context, index) {
                    final device = controller.devices[index];
                    return Card(
                      elevation: 2,
                      child: ListTile(
                        title: Text(device.name),
                        subtitle: Text(device.id),
                        trailing: Text('RSSI: ${device.rssi}'),
                        onTap: () => controller.connectToDevice(device),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 15),
              if (controller.isConnected.value)
                Column(
                  children: [
                    Text('Connected to ${controller.connectedDeviceName}'),
                    Obx(() => Text('Received data: ${controller.receivedData}')),
                    ElevatedButton(
                      onPressed: controller.disconnectFromDevice,
                      child: const Text('Disconnect'),
                    ),
                    ElevatedButton(
                      onPressed: controller.sendRequestToEsp32,
                      child: const Text('Send Data'),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
      floatingActionButton: GetX<BleController>(
        init: BleController(),
        builder: (controller) {
          return FloatingActionButton(
            onPressed: controller.isScanning.value ? controller.stopScanning : controller.scanDevices,
            child: Icon(controller.isScanning.value ? Icons.stop : Icons.play_arrow),
          );
        },
      ),
    );
  }
}
