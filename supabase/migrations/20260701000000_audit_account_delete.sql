-- Extend the audit trail to cover in-app account deletion. Unlike the preceptor
-- lifecycle actions, `account_delete` is a per-member action with no session, so
-- session_id becomes nullable and the action CHECK is widened.
alter table audit_log alter column session_id drop not null;

alter table audit_log drop constraint if exists audit_log_action_check;
alter table audit_log add constraint audit_log_action_check
  check (action in (
    'session_start',
    'end_attendance',
    'meditation_start',
    'meditation_stop',
    'account_delete'
  ));
