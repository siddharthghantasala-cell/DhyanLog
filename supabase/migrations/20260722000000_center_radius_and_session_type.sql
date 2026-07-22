-- Per-venue capture radius + session type.
--
-- Two kinds of session now exist:
--   * satsang — held at a registered center; the capture circle is centered on
--     the CENTER and sized by that center's own `check_radius_meters` (an
--     auditorium ground can be 2km across; a small hall a few hundred metres).
--   * regular — a small home sitting; anchored on the preceptor's GPS with a
--     tight default radius (see DEFAULT_REGULAR_RADIUS_METERS in the edge fn).
--
-- The radius is decided server-side at session start (never trusted from the
-- client): a satsang reads it from this table, a regular uses the default. It
-- travels with the session (into the buffer, the checkpoint, and the final row)
-- so `findNearby` can match each session against its own radius.

-- Each center carries the distance (metres) within which an abhyasi is
-- considered present at that center's satsang.
alter table meditation_centers
  add column if not exists check_radius_meters int not null default 200;

-- Seed / refresh the known centers with venue-scale placeholder radii. Ids and
-- coordinates match the client SeedData so a picked center resolves here.
insert into meditation_centers (id, name, latitude, longitude, address, check_radius_meters)
values
  ('CTR-CHN-01', 'Chennai Heartfulness Center', 13.0827, 80.2707, 'Chennai, Tamil Nadu',   500),
  ('CTR-PAR-01', 'Paris Meditation Hall',        48.8566,  2.3522, 'Paris, France',         300),
  ('CTR-KANHA',  'Kanha Shanti Vanam',           17.1860, 78.2050, 'Hyderabad, Telangana', 2000)
on conflict (id) do update set
  name                = excluded.name,
  latitude            = excluded.latitude,
  longitude           = excluded.longitude,
  address             = excluded.address,
  check_radius_meters = excluded.check_radius_meters;

-- Session type + the radius actually applied to it. Nullable so pre-existing
-- rows (which predate the concept) stay honest as "unknown"; every new row sets
-- both. The most important stat is preceptor vs abhyasi; `type` adds the
-- satsang/regular axis on top of that.
alter table meditation_sessions
  add column if not exists type text
    check (type is null or type in ('satsang', 'regular'));
alter table meditation_sessions
  add column if not exists match_radius_meters int;

-- Carry the same two fields through the durability checkpoint so a session
-- recovered after a buffer loss finalizes with its real type/radius.
alter table session_checkpoints
  add column if not exists type text;
alter table session_checkpoints
  add column if not exists match_radius_meters int;
