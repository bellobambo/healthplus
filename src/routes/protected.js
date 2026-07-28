const express = require('express');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

router.get('/patient', requireAuth, requireRole('PATIENT'), (req, res) => {
  res.json({ message: 'Patient access granted successfully.', user: req.profile });
});

router.get('/pharmacy', requireAuth, requireRole('PHARMACY'), (req, res) => {
  res.json({ message: 'Pharmacy access granted successfully.', user: req.profile });
});

module.exports = router;
