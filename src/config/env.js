const required = ['SUPABASE_URL', 'SUPABASE_ANON_KEY'];

function validateEnv() {
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
}

module.exports = { validateEnv };
