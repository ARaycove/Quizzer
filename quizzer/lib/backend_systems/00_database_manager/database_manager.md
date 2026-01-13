The database manager consists of the following

1. A local database
2. A monitor to regulate access to the local database
3. Individual files to contain access functions for differrent tables, refactoring efforts will clean these table files up to only include table definitions and sync related functions for the specific table.



The goal of the database manager is to ensure that there are no conflicts or errors when multiple sub-systems try to use the database