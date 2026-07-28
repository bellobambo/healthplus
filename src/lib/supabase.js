const { createClient } = require('@supabase/supabase-js');
const { validateEnv } = require('../config/env');

validateEnv();

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

function supabaseForToken(accessToken) {
  return createClient(process.env.SUPABASE_URL, process.env.SUPABASE_ANON_KEY, {
    auth: { autoRefreshToken: false, persistSession: false },
    global: { headers: { Authorization: `Bearer ${accessToken}` } }
  });
}

module.exports = { supabase, supabaseForToken };
