const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

router.get('/patient', requireAuth, requireRole('PATIENT'), (req, res) => {
  res.json({ message: 'Patient-only access granted.', user: req.profile });
});

router.get('/pharmacy', requireAuth, requireRole('PHARMACY'), (req, res) => {
  res.json({ message: 'Pharmacy-only access granted.', user: req.profile });
});

module.exports = router;
