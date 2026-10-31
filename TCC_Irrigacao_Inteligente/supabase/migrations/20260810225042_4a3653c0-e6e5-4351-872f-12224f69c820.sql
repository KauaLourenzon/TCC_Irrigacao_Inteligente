CREATE TABLE public.plant (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL DEFAULT 'Minha plantinha',
  mode text NOT NULL DEFAULT 'auto',
  moisture_threshold integer NOT NULL DEFAULT 35,
  schedule_times text[] NOT NULL DEFAULT ARRAY['08:00']::text[],
  schedule_days integer[] NOT NULL DEFAULT ARRAY[0,1,2,3,4,5,6]::integer[],
  water_requested_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.readings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  soil_moisture numeric NOT NULL,
  temperature numeric,
  recorded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.waterings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source text NOT NULL DEFAULT 'manual',
  soil_moisture numeric,
  watered_at timestamptz NOT NULL DEFAULT now()
);

GRANT SELECT, INSERT, UPDATE ON public.plant TO anon, authenticated;
GRANT ALL ON public.plant TO service_role;
GRANT SELECT, INSERT ON public.readings TO anon, authenticated;
GRANT ALL ON public.readings TO service_role;
GRANT SELECT, INSERT ON public.waterings TO anon, authenticated;
GRANT ALL ON public.waterings TO service_role;

ALTER TABLE public.plant ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.waterings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "plant readable by everyone" ON public.plant FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "plant updatable by everyone" ON public.plant FOR UPDATE TO anon, authenticated USING (true) WITH CHECK (true);
CREATE POLICY "plant insertable by everyone" ON public.plant FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "readings readable by everyone" ON public.readings FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "readings insertable by everyone" ON public.readings FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE POLICY "waterings readable by everyone" ON public.waterings FOR SELECT TO anon, authenticated USING (true);
CREATE POLICY "waterings insertable by everyone" ON public.waterings FOR INSERT TO anon, authenticated WITH CHECK (true);

CREATE INDEX readings_recorded_at_idx ON public.readings (recorded_at DESC);
CREATE INDEX waterings_watered_at_idx ON public.waterings (watered_at DESC);

INSERT INTO public.plant (name) VALUES ('Verdinha');

INSERT INTO public.readings (soil_moisture, temperature, recorded_at) VALUES
  (52, 23.4, now() - interval '4 hours'),
  (47, 24.1, now() - interval '3 hours'),
  (44, 24.8, now() - interval '2 hours'),
  (41, 25.2, now() - interval '1 hour'),
  (38, 25.6, now());

INSERT INTO public.waterings (source, soil_moisture, watered_at) VALUES
  ('auto', 30, now() - interval '3 days'),
  ('scheduled', 32, now() - interval '2 days'),
  ('manual', 29, now() - interval '20 hours');

ALTER PUBLICATION supabase_realtime ADD TABLE public.readings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.waterings;
ALTER PUBLICATION supabase_realtime ADD TABLE public.plant;