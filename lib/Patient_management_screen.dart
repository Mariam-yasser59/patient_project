import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
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

  _loadPatients() async {
    final data = await DatabaseHelper.instance.queryAll();
    setState(() => patientsList = data);
  }

  // --- تصدير إكسيل ---
  _exportData() async {
    try {
      List<Patient> allPatients = await DatabaseHelper.instance.queryAll();
      if (allPatients.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("لا توجد بيانات لتصديرها")));
        return;
      }

      var excel = excel_lib.Excel.createExcel();
      excel_lib.Sheet sheetObject = excel['المرضى'];
      excel.delete('Sheet1');

      sheetObject.appendRow([
        excel_lib.TextCellValue('رقم الملف'),
        excel_lib.TextCellValue('الاسم'),
        excel_lib.TextCellValue('رقم الهاتف'),
        excel_lib.TextCellValue('تاريخ الميلاد'),
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
      final filePath = '${directory.path}/patients_clinic_report.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);

      await Share.shareXFiles([XFile(file.path)], text: 'تقرير المرضى');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في التصدير: $e")));
    }
  }

  // --- استيراد إكسيل ---
  _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null) return; // لو كنسل الاختيار يقفل العملية بسلام

      var bytes = File(result.files.single.path!).readAsBytesSync();
      var excel = excel_lib.Excel.decodeBytes(bytes);

      for (var table in excel.tables.keys) {
        var sheet = excel.tables[table];
        if (sheet == null) continue;

        for (int i = 1; i < sheet.maxRows; i++) {
          var row = sheet.rows[i];
          if (row.length >= 4) {
            String fNum = row[0]?.value?.toString() ?? "";
            String pName = row[1]?.value?.toString() ?? "";
            String pPhone = row[2]?.value?.toString() ?? "";
            String bDate = row[3]?.value?.toString() ?? "";

            if (pName.isNotEmpty) {
              await DatabaseHelper.instance.insert(Patient(
                fileNumber: fNum,
                name: pName,
                phone: pPhone,
                birthDate: bDate,
              ));
            }
          }
        }
      }
      _loadPatients();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم الاستيراد بنجاح")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في الاستيراد: $e")));
    }
  }

  _addPatient() async {
    if (nameController.text.isEmpty || selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أكمل البيانات")));
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
    nameController.clear(); phoneController.clear();
    setState(() => selectedDate = null);
    _loadPatients();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildInputCard(),
            const SizedBox(height: 20),
            _buildSearchField(),
            const SizedBox(height: 10),
            _buildListView(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomButtons(),
    );
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(child: ElevatedButton.icon(onPressed: _exportData, icon: const Icon(Icons.table_view), label: const Text("تصدير"))),
          const SizedBox(width: 10),
          Expanded(child: ElevatedButton.icon(onPressed: _importData, icon: const Icon(Icons.download), label: const Text("استيراد"))),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
      child: Column(
        children: [
          _inputField("الاسم", nameController, Icons.person),
          _inputField("الهاتف", phoneController, Icons.phone),
          ListTile(
            onTap: () => _selectDate(context),
            title: Text(selectedDate == null ? "تاريخ الميلاد" : DateFormat('yyyy-MM-dd').format(selectedDate!)),
            trailing: const Icon(Icons.calendar_today),
          ),
          ElevatedButton(onPressed: _addPatient, child: const Text("إضافة"))
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, IconData icon) {
    return TextField(controller: controller, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)));
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (val) async => setState(() async => patientsList = await DatabaseHelper.instance.search(val)),
      decoration: InputDecoration(hintText: "بحث...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: patientsList.length,
      itemBuilder: (ctx, i) => Card(child: ListTile(title: Text(patientsList[i].name), subtitle: Text("#${patientsList[i].fileNumber}"))),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
    if (picked != null) setState(() => selectedDate = picked);
  }
}