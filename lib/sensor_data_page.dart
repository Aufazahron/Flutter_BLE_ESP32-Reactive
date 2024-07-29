import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'ble_controller.dart';

class SensorDataPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final BleController bleController = Get.find();
    final Rx<int> _rowsPerPage = PaginatedDataTable.defaultRowsPerPage.obs;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Data'),
        centerTitle: true,
      ),
      body: Obx(() {
        return SingleChildScrollView(
          child: PaginatedDataTable(
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Location')),
              DataColumn(label: Text('Type')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Clock')),
              DataColumn(label: Text('O3')),
              DataColumn(label: Text('NO2')),
              DataColumn(label: Text('SO2')),
              DataColumn(label: Text('NMHC')),
              DataColumn(label: Text('NH3')),
              DataColumn(label: Text('H2S')),
            ],
            source: SensorDataTableSource(bleController.sensorDataList),
            rowsPerPage: _rowsPerPage.value,
            availableRowsPerPage: const <int>[10, 15, 50, 100],
            onRowsPerPageChanged: (int? value) {
              if (value != null) {
                _rowsPerPage.value = value;
              }
            },
          ),
        );
      }),
    );
  }
}

class SensorDataTableSource extends DataTableSource {
  final RxList<Map<String, dynamic>> sensorDataList;

  SensorDataTableSource(this.sensorDataList);

  @override
  DataRow? getRow(int index) {
    if (index >= sensorDataList.length) return null;
    final sensorData = sensorDataList[index];
    return DataRow(cells: [
      DataCell(Text(sensorData['ID'] ?? '')),
      DataCell(Text(sensorData['Location'] ?? '')),
      DataCell(Text(sensorData['Type'] ?? '')),
      DataCell(Text(sensorData['Date'] ?? '')),
      DataCell(Text(sensorData['Clock'] ?? '')),
      DataCell(Text(sensorData['O3'] ?? '')),
      DataCell(Text(sensorData['NO2'] ?? '')),
      DataCell(Text(sensorData['SO2'] ?? '')),
      DataCell(Text(sensorData['NMHC'] ?? '')),
      DataCell(Text(sensorData['NH3'] ?? '')),
      DataCell(Text(sensorData['H2S'] ?? '')),
    ]);
  }

  @override
  bool get isRowCountApproximate => false;

  @override
  int get rowCount => sensorDataList.length;

  @override
  int get selectedRowCount => 0;
}
