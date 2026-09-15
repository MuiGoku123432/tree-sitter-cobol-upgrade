; EXEC SQL extraction contract (Phase 4, D-17/D-18).
; Direct named-node captures only: no predicates. Consumers assign each role
; to the unique smallest enclosing @statement range, then subtract CTE
; definitions from same-statement source candidates before treating names as
; physical tables.

(exec_sql_statement) @statement

(sql_table_name) @table

(sql_table_alias) @alias

(sql_include_name) @include

(sql_dynamic_source) @dynamic_source

(sql_cte_definition) @cte_definition

(sql_source_candidate) @source_candidate
