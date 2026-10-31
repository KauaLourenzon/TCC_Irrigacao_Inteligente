import { supabase } from "@/integrations/supabase/client";

export type SpeciesProfile = {
  id: string;
  common_name: string;
  scientific_name: string | null;
  ideal_moisture_min: number;
  ideal_moisture_max: number;
  ideal_temp_min: number;
  ideal_temp_max: number;
  watering_frequency_days: number;
  light_needs: "low" | "indirect" | "direct";
  care_notes: string | null;
};

export async function fetchSpeciesProfiles(): Promise<SpeciesProfile[]> {
  const { data, error } = await supabase
    .from("species_profiles")
    .select(
      "id, common_name, scientific_name, ideal_moisture_min, ideal_moisture_max, ideal_temp_min, ideal_temp_max, watering_frequency_days, light_needs, care_notes",
    )
    .order("common_name", { ascending: true });
  if (error) throw error;
  return (data ?? []) as SpeciesProfile[];
}