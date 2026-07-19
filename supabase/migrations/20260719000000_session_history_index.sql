-- Personal meditation history.
--
-- "Which sessions did I attend?" is already answerable from the data we store:
-- every finalized session row carries its full attendee_ids array. What it
-- lacked was an access path — without an index that question is a sequential
-- scan over every session ever recorded.
--
-- A GIN index makes array containment (attendee_ids @> ARRAY['HFN-ABHY-001'])
-- an index lookup. This deliberately adds NO new table and NO new write: the
-- one-row-per-session invariant is untouched, and history is derived from the
-- same single row the meditation-stop flush already writes.
create index if not exists idx_sessions_attendees
  on meditation_sessions using gin (attendee_ids);

-- History is read newest-first and filtered by member. The existing
-- idx_sessions_preceptor covers the "sessions I led" half; this composite lets
-- the ordering be served from the index rather than re-sorted per query.
create index if not exists idx_sessions_preceptor_started
  on meditation_sessions (preceptor_id, start_attendance_at desc);
