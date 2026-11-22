export type UserRole = "admin" | "restaurant_owner" | "client" | "driver";

export type OrderStatus =
  | "pending"
  | "accepted"
  | "rejected"
  | "ready_for_pickup"
  | "driver_assigned"
  | "picked_up"
  | "delivered"
  | "cancelled";

export interface Profile {
  id: string;
  role: UserRole;
  full_name: string;
  phone: string | null;
  avatar_url: string | null;
  created_at: string;
}

export interface Restaurant {
  id: string;
  owner_id: string;
  name: string;
  description: string | null;
  cuisine_type: string | null;
  logo_url: string | null;
  cover_image_url: string | null;
  address: string;
  phone: string | null;
  latitude: number;
  longitude: number;
  is_open: boolean;
  is_approved: boolean;
  avg_prep_time_minutes: number;
  created_at: string;
}

export interface DriverProfile {
  id: string;
  vehicle_type: string | null;
  license_plate: string | null;
  is_online: boolean;
  is_approved: boolean;
  profiles?: Profile; // joined
}

export interface Order {
  id: string;
  client_id: string;
  restaurant_id: string;
  driver_id: string | null;
  status: OrderStatus;
  subtotal_cents: number;
  delivery_fee_cents: number;
  total_cents: number;
  payment_method: string;
  payment_status: string;
  created_at: string;
  restaurants?: Pick<Restaurant, "name">; // joined
  profiles?: Pick<Profile, "full_name">; // joined client
}
