-- Schedule the analytics expansion off the hot path. expand_attendance() fans
-- meditation_sessions.attendee_ids into attendance_expanded; run it monthly so
-- the write path stays one-row-per-session.

create extension if not exists pg_cron;

-- Idempotent (re)scheduling so re-running this migration is safe.
do $$
begin
  if exists (select 1 from cron.job where jobname = 'monthly-expand-attendance') then
    perform cron.unschedule('monthly-expand-attendance');
  end if;
end $$;

-- 03:00 UTC on the 1st of each month.
select cron.schedule(
  'monthly-expand-attendance',
  '0 3 1 * *',
  $$select expand_attendance();$$
);
