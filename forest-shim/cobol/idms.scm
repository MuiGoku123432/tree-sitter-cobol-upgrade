; IDMS DML extraction query (Phase 2, D-04): record/set names + verb.
(idms_navigation_statement
  verb: (_) @verb
  (idms_record_name) @record)

(idms_navigation_statement
  (idms_set_name) @set)

(idms_update_statement
  (idms_record_name) @record)

(idms_update_statement
  (idms_set_name) @set)

(idms_session_statement
  (idms_record_name) @record)

; ACCEPT stays hidden, so this single-verb statement node identifies the verb.
(idms_accept_statement
  (idms_record_name) @record) @verb
