const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const authRoutes = require('./routes/auth');
const protectedRoutes = require('./routes/protected');

const app = express();
app.use(helmet());
app.use(cors({ origin: process.env.CLIENT_ORIGIN?.split(',') || true }));
app.use(express.json({ limit: '1mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

app.get('/health', (_req, res) => res.json({ status: 'ok' }));
app.use('/api/auth', authRoutes);
app.use('/api', protectedRoutes);

app.use((_req, res) => res.status(404).json({ error: 'Route not found.' }));
app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ error: 'An unexpected server error occurred.' });
});

module.exports = app;
