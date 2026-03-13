import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'database_helper.dart';
import 'patient_model.dart';

class PatientManagementScreen extends StatefulWidget {
  const PatientManagementScreen({super.key});

  @override
  State<PatientManagementScreen> createState() => _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  DateTime? selectedDate;
  List<Patient> patientsList = [];

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  // تحميل البيانات
  Future<void> _loadPatients() async {
    final data = await DatabaseHelper.instance.queryAll();
    setState(() => patientsList = data);
  }

  // إضافة مريض جديد
  Future<void> _addPatient() async {
    if (nameController.text.isEmpty || selectedDate == null || phoneController.text.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("برجاء إكمال البيانات وكتابة 11 رقم للهاتف")),
      );
      return;
    }

    int count = await DatabaseHelper.instance.getPatientsCount();
    String autoFileNumber = (1001 + count).toString();
    String formattedDate = DateFormat('yyyy-MM-dd').format(selectedDate!);

    await DatabaseHelper.instance.insert(Patient(
      name: nameController.text,
      phone: phoneController.text,
      fileNumber: autoFileNumber,
      birthDate: formattedDate,
    ));

    nameController.clear();
    phoneController.clear();
    setState(() => selectedDate = null);
    _loadPatients();
  }

  // تصدير البيانات
  Future<void> _exportData() async {
    try {
      List<Patient> allPatients = await DatabaseHelper.instance.queryAll();
      if (allPatients.isEmpty) return;

      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheetObject = excel['المرضى'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        excel_lib.TextCellValue('رقم الملف'),
        excel_lib.TextCellValue('الاسم'),
        excel_lib.TextCellValue('رقم الهاتف'),
        excel_lib.TextCellValue('تاريخ الميلاد')
      ]);

      for (var p in allPatients) {
        sheetObject.appendRow([
          excel_lib.TextCellValue(p.fileNumber),
          excel_lib.TextCellValue(p.name),
          excel_lib.TextCellValue(p.phone),
          excel_lib.TextCellValue(p.birthDate),
        ]);
      }

      var fileBytes = excel.save();
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/patients_report.xlsx');
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(file.path)], text: 'تقرير المرضى');
    } catch (e) {
      debugPrint("Export Error: $e");
    }
  }

  // استيراد البيانات
  Future<void> _importData() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = excel_lib.Excel.decodeBytes(bytes);
      // منطق الاستيراد هنا...
      _loadPatients();
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        title: const Text("إدارة بيانات المرضى", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF2185D0),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildInputCard(),
          ),
          Expanded(
            child: _buildListView(),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(child: ElevatedButton.icon(onPressed: _exportData, icon: const Icon(Icons.table_view), label: const Text("تصدير"))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(onPressed: _importData, icon: const Icon(Icons.download), label: const Text("استيراد"))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: "الاسم")),
          TextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
            decoration: const InputDecoration(labelText: "رقم الهاتف"),
          ),
          ListTile(
            title: Text(selectedDate == null ? "اختر تاريخ الميلاد" : DateFormat('yyyy-MM-dd').format(selectedDate!)),
            trailing: const Icon(Icons.calendar_month),
            onTap: () => _selectDate(context),
          ),
          ElevatedButton(onPressed: _addPatient, child: const Text("إضافة مريض")),
        ],
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: patientsList.length,
      itemBuilder: (context, index) {
        final p = patientsList[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ListTile(
            title: Text(p.name),
            subtitle: Text("الهاتف: ${p.phone} - الملف: ${p.fileNumber}"),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () async {
                await DatabaseHelper.instance.delete(p.id!);
                _loadPatients();
              },
            ),
          ),
        );
      },
    );
  }
}