const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const authRoutes = require('./routes/auth');
const protectedRoutes = require('./routes/protected');

const app = express();
app.use(helmet());
// Open CORS for the MVP so any frontend client can call the API.
// Restrict this to the deployed frontend domain before production launch.
app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(morgan(process.env.NODE_ENV === 'production' ? 'combined' : 'dev'));

app.get('/', (_req, res) => res.json({
  message: 'Welcome to the Health + API.',
  name: 'Health + API',
  tagline: 'Your pharmacy, delivered.',
  description: 'Health + helps patients find and order medication from pharmacies, while giving pharmacies a simple way to manage their accounts and orders.',
  status: 'online',
  endpoints: {
    health: '/health',
    signup: '/api/auth/signup',
    login: '/api/auth/login',
    currentUser: '/api/auth/me'
  }
}));

app.get('/health', (_req, res) => res.json({ message: 'Health + API is running.', status: 'ok' }));
app.use('/api/auth', authRoutes);
app.use('/api', protectedRoutes);

app.use((_req, res) => res.status(404).json({
  error: 'Route not found.',
  message: 'The requested endpoint does not exist. Check the URL and HTTP method.'
}));
app.use((error, _req, res, _next) => {
  console.error(error);
  res.status(500).json({ error: 'An unexpected server error occurred.', message: 'Please try again later.' });
});

module.exports = app;
