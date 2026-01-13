All tables are now class objects where
Every Table class will have these exact method names:
Example Template as Expected:

Transient tables store and collect information and when internet is available this data is synced to the server and then removed from the local device.
Non transient tables are for persistent storage such as the question answer pair table

class NameTable {
    static final NameTable _instance = NameTable._internal();
    factory NameTable() => _instance;
    NameTable._internal();
  // ==================================================
  // ----- Constants -----
  // ==================================================
  bool isTransient = true;

  // ==================================================
  // ----- Schema Definition Validation -----
  // ==================================================
  final String _tableName                         = 'citations';
  final List<String> _primaryKeyConstraints       = [];
  static final List<Map<String, String>> _expectedColumns = []

  Future<void> verifyTable(db) async{
    await table_helper.verifyTable(db: db, tableName: _tableName, expectedColumns: _expectedColumns, primaryKeyColumns: _primaryKeyConstraints);
  }

  // ==================================================
  // ----- CRUD operations -----
  // ==================================================

  Future<void> addRecord();

  Future<void> deleteRecord();

  Future<void> editRecord();

  Future<List<Map<String, dynamic>>> getRecord(String sqlQuery); //To be generic, allowing for custom queries to be passed in for more complex logic

    // ==================================================
    // ----- Sync Operations -----
    // ==================================================
    upsertRecord() // adds or edits the existing record (if existing record)

    batchUpsertRecord()

    getUnsyncedRecords()

    updateSyncFlags()
}
