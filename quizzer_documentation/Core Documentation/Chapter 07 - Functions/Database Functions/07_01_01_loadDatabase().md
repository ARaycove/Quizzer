If the user has installed for the first time, initial copy of database will be generated. This will be updated over time

Otherwise loads the existing DB into memory and ensure all fields for all tables are present and accurate

This function does not produce fields inside of tables

It will initialize empty tables, when the tables actually come into use a separate function will be called to initialize the fields.

