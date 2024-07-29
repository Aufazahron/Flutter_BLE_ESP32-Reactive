import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'ble_controller.dart';

class ChartPage extends StatelessWidget {
  final BleController bleController = Get.find();
  final List<int> dataRanges = [10, 25, 50, 75, 100];
  final RxInt selectedRange = 50.obs;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sensor Data Charts'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Obx(()=> DropdownButton<int>(
            value: selectedRange.value,
            items: dataRanges.map((int range) {
              return DropdownMenuItem<int>(
                value: range,
                child: Text('Last $range data'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                selectedRange.value = value;
              }
            },
          ),),
          Expanded(
            child: ListView(
              children: [
                _buildChart('O3', 'O3 (ppm)'),
                _buildChart('NO2', 'NO2 (ppm)'),
                _buildChart('SO2', 'SO2 (ppm)'),
                _buildChart('NMHC', 'NMHC (ppm)'),
                _buildChart('NH3', 'NH3 (ppm)'),
                _buildChart('H2S', 'H2S (ppm)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(String sensorKey, String title) {
    return Obx(() {
      final data = bleController.sensorDataList.reversed
          .take(selectedRange.value)
          .toList() // Convert iterable to list to use reversed
          .reversed // Reverse the order
          .map((data) => SensorDataPoint(
                x: data['Date'] + ' ' + data['Clock'],
                y: double.tryParse(data[sensorKey]) ?? 0.0,
              ))
          .toList();


      return Card(
        elevation: 4,
        margin: const EdgeInsets.all(10),
        child: SfCartesianChart(
          title: ChartTitle(text: title),
          legend: Legend(isVisible: false),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: <ChartSeries>[
            LineSeries<SensorDataPoint, String>(
              dataSource: data,
              xValueMapper: (SensorDataPoint data, _) => data.x,
              yValueMapper: (SensorDataPoint data, _) => data.y,
              name: sensorKey,
              dataLabelSettings: const DataLabelSettings(isVisible: true),
            )
          ],
          primaryXAxis: CategoryAxis(
            majorGridLines: const MajorGridLines(width: 0),
          ),
          primaryYAxis: NumericAxis(
            edgeLabelPlacement: EdgeLabelPlacement.shift,
            title: AxisTitle(text: 'Value'),
            majorGridLines: const MajorGridLines(width: 0),
          ),
        ),
      );
    });
  }
}

class SensorDataPoint {
  SensorDataPoint({required this.x, required this.y});
  final String x;
  final double y;
}
