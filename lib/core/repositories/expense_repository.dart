import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../database/database_tables.dart';
import '../models/expense.dart';

class ExpenseRepository {
  final DatabaseHelper _dbHelper;
  ExpenseRepository([DatabaseHelper? dbHelper])
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<List<Expense>> getExpenses({
    String? category,
    String? fromDate,
    String? toDate,
  }) async {
    final db = await _dbHelper.database;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (category != null && category.isNotEmpty && category != 'All') {
      whereClauses.add('category = ?');
      whereArgs.add(category);
    }

    if (fromDate != null && fromDate.isNotEmpty) {
      whereClauses.add('expense_date >= ?');
      whereArgs.add(fromDate);
    }

    if (toDate != null && toDate.isNotEmpty) {
      whereClauses.add('expense_date <= ?');
      whereArgs.add(toDate);
    }

    final whereString = whereClauses.isNotEmpty
        ? whereClauses.join(' AND ')
        : null;
    final maps = await db.query(
      DatabaseTables.expenses,
      where: whereString,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'expense_date DESC, id DESC',
    );

    return maps.map((e) => Expense.fromMap(e)).toList();
  }

  Future<int> insertExpense(Expense expense) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toIso8601String();
    final map = expense.copyWith(createdAt: now).toMap();
    return await db.insert(DatabaseTables.expenses, map);
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseTables.expenses,
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<int> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      DatabaseTables.expenses,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<double> getTotalExpensesForDate(String date) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COALESCE(SUM(amount), 0) as total FROM ${DatabaseTables.expenses} WHERE expense_date = ?',
      [date],
    );
    return (res.first['total'] as num?)?.toDouble() ?? 0.0;
  }
}
