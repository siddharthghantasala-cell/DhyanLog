-- Seed data mirroring lib/services/mock/seed_data.dart so the real backend
-- behaves like the mock during development.

insert into participants (heartfulness_id, name, age, address, email, phone, role) values
  ('HFN-PREC-001',  'Asha Rao',       52, '12 Lotus St, Chennai',          'asha.rao@example.org', '+91 90000 11111', 'preceptor'),
  ('HFN-PREC-002',  'Daniel Mertens', 47, '8 Rue du Calme, Paris',         'daniel.m@example.org', '+33 6 00 00 22 22', 'preceptor'),
  ('HFN-MASTER-000','Revered Master',  70, 'Kanha Shanti Vanam, Hyderabad', 'master@example.org',   '+91 90000 00000', 'master'),
  ('HFN-ABHY-001',  'Meera Nair',     29, '45 Jasmine Rd, Chennai',        'meera.n@example.org',  '+91 90000 33333', 'abhyasi'),
  ('HFN-ABHY-002',  'Carlos Mendez',  34, '20 Calle Sol, Madrid',          'carlos.m@example.org', '+34 600 44 44 44', 'abhyasi'),
  ('HFN-ABHY-003',  'Yuki Tanaka',    41, '3 Sakura Ave, Kyoto',           'yuki.t@example.org',   '+81 90 0000 5555', 'abhyasi')
on conflict (heartfulness_id) do nothing;

insert into meditation_centers (id, name, latitude, longitude, address) values
  ('CTR-CHN-01', 'Chennai Heartfulness Center', 13.0827, 80.2707, 'Chennai, Tamil Nadu'),
  ('CTR-PAR-01', 'Paris Meditation Hall',       48.8566, 2.3522,  'Paris, France'),
  ('CTR-KANHA',  'Kanha Shanti Vanam',          17.1860, 78.2050, 'Hyderabad, Telangana')
on conflict (id) do nothing;
