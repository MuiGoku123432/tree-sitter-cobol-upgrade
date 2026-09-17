; IDMS DML extraction query (Phase 2, D-04): exact verb tokens plus
; syntax-grounded record and set names.
(idms_navigation_statement
  verb: (_) @verb)

(idms_navigation_statement
  (idms_record_name) @record)

(idms_navigation_statement
  (idms_set_name) @set)

(idms_update_statement
  verb: (_) @verb)

(idms_update_statement
  (idms_record_name) @record)

(idms_update_statement
  (idms_set_name) @set)

(idms_session_statement
  verb: (_) @verb)

(idms_session_statement
  verb: (BIND)
  (idms_record_name) @record)

(idms_accept_statement
  verb: (_) @verb)

(idms_accept_statement
  (idms_record_name) @record)
