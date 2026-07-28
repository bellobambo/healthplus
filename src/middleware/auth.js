const { supabase, supabaseForToken } = require('../lib/supabase');

async function requireAuth(req, res, next) {
  const authorization = req.headers.authorization;
  if (!authorization?.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'A Bearer access token is required.', message: 'Sign in first, then send your access token as a Bearer token.' });
  }

  const token = authorization.slice('Bearer '.length);
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data.user) {
    return res.status(401).json({ error: 'Your session is invalid or has expired.', message: 'Please sign in again to get a new access token.' });
  }

  const { data: profile, error: profileError } = await supabaseForToken(token)
    .from('profiles')
    .select('id, full_name, phone, role, created_at')
    .eq('id', data.user.id)
    .single();

  if (profileError || !profile) {
    return res.status(403).json({ error: 'Account profile is unavailable.', message: 'Your account profile could not be loaded. Please contact support.' });
  }

  req.user = data.user;
  req.profile = profile;
  req.accessToken = token;
  if (profile.role === 'PHARMACY') {
    const { data: pharmacy } = await supabaseForToken(token)
      .from('pharmacies')
      .select('id, pharmacy_name, verified')
      .eq('owner_id', data.user.id)
      .single();
    req.pharmacy = pharmacy;
  }
  next();
}

function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.profile || !roles.includes(req.profile.role)) {
      return res.status(403).json({ error: 'You do not have access to this resource.', message: `This endpoint is available only to: ${roles.join(', ')}.` });
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };
