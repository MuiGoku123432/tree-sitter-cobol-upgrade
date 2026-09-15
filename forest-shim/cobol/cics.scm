; EXEC CICS extraction query (Phase 3, D-24): command word plus the four
; criterion operands.
;
; One pattern per capture role, never one pattern with alternations, and no
; predicates of any kind. gortex's runQuery iterates matches and copies
; captures with NO predicate evaluation whatsoever, so a predicate here would
; compile and then be silently ignored, matching every option against every
; capture (D-21 evidence). Silent failure is worse than loud failure.
;
; D-22 DISCLOSURE. The program capture below satisfies criterion 1 literally,
; but it generally yields a VARIABLE rather than a resolvable edge target:
; 30 of the 33 measured PROGRAM operands are data names, not quoted literals.
; A consumer treating @program as a program name will be wrong roughly 91% of
; the time on the measured sample. The operand must be resolved through the
; DATA DIVISION before it becomes an edge.
;
; D-24: this file is a published contract with no reader today. Nothing in
; gortex consumes it yet; it exists so the nodes are extractable on the
; contract the graph layer will later read.

(exec_cics_statement
  command: (WORD) @command)

(cics_transaction_name) @transaction

(cics_program_name) @program

(cics_map_name) @map

(cics_mapset_name) @mapset
