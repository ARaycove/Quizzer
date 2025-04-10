import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';


class QuizzerDatabase {
  static final QuizzerDatabase instance = QuizzerDatabase._instance();
  static Database? _database;

  QuizzerDatabase._instance();

  Future<Database> get db async {
    _database ??= await initDb();
    return _database!;
  }

  Future<Database> initDb() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'quizzer.db');print(path);

    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    // Creating all planned tables for quizzer_db
    // user_profiles table
    await db.execute('''
      CREATE TABLE user_profiles ()
    ''');
    // login_attempts table
    await db.execute('''

    ''');
    // source_materials
    await db.execute('''

    ''');
    //
  }

  // UserProfile Operations





  // Question-Answer Pair Table Operations

  
  // Future<int> insertUser(User user) async {
  //   Database db = await instance.db;
  //   return await db.insert('gfg_users', user.toMap());
  // }

  // Future<List<Map<String, dynamic>>> queryAllUsers() async {
  //   Database db = await instance.db;
  //   return await db.query('gfg_users');
  // }

  // Future<int> updateUser(User user) async {
  //   Database db = await instance.db;
  //   return await db.update('gfg_users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  // }

  // Future<int> deleteUser(int id) async {
  //   Database db = await instance.db;
  //   return await db.delete('gfg_users', where: 'id = ?', whereArgs: [id]);
  // }

  // Future<void> initializeUsers() async {
  //   List<User> usersToAdd = [
  //     User(username: 'John', email: 'john@example.com'),
  //     User(username: 'Jane', email: 'jane@example.com'),
  //     User(username: 'Alice', email: 'alice@example.com'),
  //     User(username: 'Bob', email: 'bob@example.com'),
  //   ];

  //   for (User user in usersToAdd) {
  //     await insertUser(user);
  //   }
  // }
}