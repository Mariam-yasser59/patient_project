import 'dart:io';
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
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير المرضى');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في التصدير: $e")));
    }
  }

  _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
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
        children: [
          const SizedBox(height: 10),
        ],
      ),
          child: Row(
            children: [
              const SizedBox(width: 10),
            ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
      child: Column(
        children: [
          _inputField("الاسم", nameController, Icons.person),
          _inputField("الهاتف", phoneController, Icons.phone),
          ListTile(
            onTap: () => _selectDate(context),
            title: Text(selectedDate == null ? "تاريخ الميلاد" : DateFormat('yyyy-MM-dd').format(selectedDate!)),
          ),
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, IconData icon) {
  }

  Widget _buildSearchField() {
    return TextField(
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      itemCount: patientsList.length,
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
    if (picked != null) setState(() => selectedDate = picked);
  }
}