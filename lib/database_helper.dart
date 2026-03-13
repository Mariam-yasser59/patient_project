import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'patient_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('clinic_final_v2.db'); // حافظت على اسم قاعدة البيانات الحالي
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE patients(
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        name TEXT, 
        phone TEXT, 
        fileNumber TEXT,
        birthDate TEXT
      )
    ''');
  }

  // دالة لحساب عدد المرضى (مهمة لتوليد رقم الملف التلقائي)
  Future<int> getPatientsCount() async {
    final db = await instance.database;
    final res = await db.rawQuery('SELECT COUNT(*) FROM patients');
    return Sqflite.firstIntValue(res) ?? 0;
  }

  // إضافة مريض جديد
  Future<int> insert(Patient patient) async {
    final db = await instance.database;
    return await db.insert('patients', patient.toMap());
  }

  // عرض كل المرضى (مرتبين من الأحدث للأقدم)
  Future<List<Patient>> queryAll() async {
    final db = await instance.database;
    final result = await db.query('patients', orderBy: "id DESC");
    return result.map((json) => Patient.fromMap(json)).toList();
  }

  // البحث عن مريض
  Future<List<Patient>> search(String key) async {
    final db = await instance.database;
    final result = await db.query('patients',
        where: "name LIKE ? OR phone LIKE ? OR fileNumber LIKE ?",
        whereArgs: ['%$key%', '%$key%', '%$key%']);
    return result.map((json) => Patient.fromMap(json)).toList();
  }

  // --- السطر القادم هو الحل لمشكلة الـ 41 خطأ التي تظهر في الواجهة ---

  // حذف مريض باستخدام الـ id
  Future<int> delete(int id) async {
    final db = await instance.database;
    return await db.delete(
      'patients',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}