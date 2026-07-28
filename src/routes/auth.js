const express = require('express');
const { supabase, supabaseForToken } = require('../lib/supabase');
const { requireAuth } = require('../middleware/auth');

const router = express.Router();
const accountRoles = new Set(['PATIENT', 'PHARMACY']);

router.post('/signup', async (req, res, next) => {
  try {
    const {
      email, password, fullName, phone, role,
      pharmacyName
    } = req.body;
    if (!email || !password || !fullName || !role) {
      return res.status(400).json({ error: 'email, password, fullName, and role are required.' });
    }
    if (password.length < 8) {
      return res.status(400).json({ error: 'Password must be at least 8 characters.' });
    }
    if (!accountRoles.has(role)) {
      return res.status(400).json({ error: 'role must be either PATIENT or PHARMACY.' });
    }
    if (role === 'PHARMACY') {
      if (!pharmacyName?.trim()) {
        return res.status(400).json({ error: 'Pharmacy registration requires pharmacyName.' });
      }
    }

    // The database trigger creates the profile and, for pharmacies, its onboarding record.
    const { data, error } = await supabase.auth.signUp({
      email: email.trim().toLowerCase(),
      password,
      options: {
        data: {
          full_name: fullName.trim(), phone: phone?.trim() || null, role,
          pharmacy_name: pharmacyName?.trim() || null
        }
      }
    });
    if (error) return res.status(400).json({ error: error.message });

    return res.status(201).json({
      message: data.session ? 'Account created.' : 'Check your email to confirm your account.',
      user: data.user ? { id: data.user.id, email: data.user.email, role } : null,
      session: data.session
        ? { accessToken: data.session.access_token, refreshToken: data.session.refresh_token, expiresAt: data.session.expires_at }
        : null
    });
  } catch (error) { next(error); }
});

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) return res.status(400).json({ error: 'email and password are required.' });

    const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim().toLowerCase(), password });
    if (error) return res.status(401).json({ error: 'Invalid email or password.' });

    const { data: profile, error: profileError } = await supabaseForToken(data.session.access_token)
      .from('profiles').select('id, full_name, phone, role, created_at').eq('id', data.user.id).single();
    if (profileError) return res.status(403).json({ error: 'Account profile is unavailable.' });

    const { data: pharmacy } = profile.role === 'PHARMACY'
      ? await supabaseForToken(data.session.access_token)
        .from('pharmacies')
        .select('id, pharmacy_name, verified')
        .eq('owner_id', data.user.id)
        .single()
      : { data: null };

    return res.json({
      user: { ...profile, email: data.user.email, pharmacy },
      session: { accessToken: data.session.access_token, refreshToken: data.session.refresh_token, expiresAt: data.session.expires_at }
    });
  } catch (error) { next(error); }
});

router.post('/logout', requireAuth, async (req, res, next) => {
  try {
    // Revokes refresh tokens. The current access JWT can remain valid until it expires.
    const { error } = await supabaseForToken(req.accessToken).auth.signOut({ scope: 'global' });
    if (error) return res.status(400).json({ error: error.message });
    return res.status(204).send();
  } catch (error) { next(error); }
});

router.get('/me', requireAuth, (req, res) => {
  res.json({ user: { ...req.profile, email: req.user.email, pharmacy: req.pharmacy || null } });
});

module.exports = router;
