// Same Supabase project as the website (web/.env.local).
// The anon key is public by design; data is protected by Row Level Security.
class Env {
  static const supabaseUrl = 'https://trljvknclahjcerffyat.supabase.co';
  static const supabaseAnonKey = 'sb_publishable_4YSw7XOfugo6JxIEjroINw_nghMj4_8';

  // The deployed Next.js app URL (Vercel). Used to send email notifications.
  // Set to '' to disable notifications during local development.
  static const appUrl = ''; // e.g. 'https://foodivo.vercel.app'
}
