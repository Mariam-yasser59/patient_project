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

  _loadPatients() async {
    final data = await DatabaseHelper.instance.queryAll();
    setState(() => patientsList = data);
  }

  // --- دالة التصدير ---
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
      String timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '${directory.path}/patients_report_$timestamp.xlsx';
      final file = File(filePath);
      await file.writeAsBytes(fileBytes!);
      await Share.shareXFiles([XFile(file.path)], text: 'تقرير المرضى');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("خطأ في التصدير: $e")));
    }
  }

  // --- دالة الاستيراد ---
  _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );
      if (result == null) return;
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
    if (nameController.text.isEmpty || selectedDate == null || phoneController.text.length < 11) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("أكمل البيانات (الهاتف 11 رقم)")));
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
      // الجسم يحتوي على الإدخال والقائمة فقط
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildInputCard(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSearchField(),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _buildListView(),
          ),
        ],
      ),
      // السر هنا: وضع الأزرار في bottomNavigationBar يجعلها تظهر بوضوح فوق شريط النظام
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportData,
                  icon: const Icon(Icons.table_view),
                  label: const Text("تصدير"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _importData,
                  icon: const Icon(Icons.download),
                  label: const Text("استيراد"),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.blue.shade100)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _inputField("الاسم", nameController, Icons.person),
          _inputField("الهاتف", phoneController, Icons.phone),
          ListTile(
            dense: true,
            onTap: () => _selectDate(context),
            title: Text(selectedDate == null ? "تاريخ الميلاد" : DateFormat('yyyy-MM-dd').format(selectedDate!)),
            trailing: const Icon(Icons.calendar_today, color: Color(0xFF2185D0)),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: _addPatient, child: const Text("إضافة")),
          )
        ],
      ),
    );
  }

  Widget _inputField(String label, TextEditingController controller, IconData icon) {
    bool isPhone = label == "الهاتف";
    return TextField(
      controller: controller,
      keyboardType: isPhone ? TextInputType.number : TextInputType.text,
      inputFormatters: isPhone ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)] : [],
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), contentPadding: const EdgeInsets.symmetric(vertical: 8)),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      onChanged: (val) async {
        final data = await DatabaseHelper.instance.search(val);
        setState(() => patientsList = data);
      },
      decoration: InputDecoration(
        hintText: "بحث...",
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: patientsList.length,
      itemBuilder: (ctx, i) {
        final p = patientsList[i];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("#${p.fileNumber}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    const Icon(Icons.phone, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(p.phone, style: const TextStyle(fontSize: 11)),
                    const SizedBox(width: 12),
                    const Icon(Icons.cake, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(p.birthDate, style: const TextStyle(fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime.now());
    if (picked != null) setState(() => selectedDate = picked);
  }
}