/**
 * =====================================================================
 * APLIKASI: SIAKAD BUSTANUL MUSTAFIDIN (SIAKAD BM)
 * File: app.js (Server Express & API Entry Point)
 * Lokasi: Palengaan Laok, Palengaan, Pamekasan
 * =====================================================================
 */

const express = require('express');
const path = require('path');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// 1. Middleware Global
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// 2. Menyajikan File Statis (HTML, CSS, JS, dan Gambar Logo)
// File HTML Anda (index.html, dashboard-guru.html, rapor-santri.html)
// dan aset logo dapat langsung diakses dari browser
app.use(express.static(path.join(__dirname)));
app.use('/assets', express.static(path.join(__dirname, 'assets')));

// 3. Routing Halaman Utama (Frontend)
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

app.get('/dashboard', (req, res) => {
  res.sendFile(path.join(__dirname, 'dashboard-guru.html'));
});

app.get('/rapor', (req, res) => {
  res.sendFile(path.join(__dirname, 'rapor-santri.html'));
});

// 4. API Health Check / Cek Status Server
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    aplikasi: 'SIAKAD Bustanul Mustafidin (SIAKAD BM)',
    lembaga: 'MD. Bustanul Mustafidin - Palengaan Laok',
    waktu: new Date().toISOString()
  });
});

// 5. API Routes Tambahan (Bila sudah mengaktifkan folder src/routes/api.js)
try {
  const apiRouter = require('./src/routes/api');
  app.use('/api', apiRouter);
  console.log('✓ Modul API terintegrasi dari src/routes/api.js - app.js:54');
} catch (err) {
  console.log('ℹ Mode Standalone / Demo (src/routes/api.js belum diaktifkan). - app.js:56');
}

// 6. Penanganan Rute Error 404 (Halaman Tidak Ditemukan)
app.use((req, res) => {
  res.status(404).send(`
    <div style="font-family: sans-serif; text-align: center; padding: 50px;">
      <h1 style="color: #065f46;">404 - Halaman Tidak Ditemukan</h1>
      <p style="color: #64748b;">Halaman yang Anda tuju tidak tersedia di SIAKAD Bustanul Mustafidin.</p>
      <a href="/" style="color: #047857; font-weight: bold; text-decoration: none;">&larr; Kembali ke Halaman Utama</a>
    </div>
  `);
});

// 7. Jalankan Server
app.listen(PORT, () => {
  console.log('==================================================== - app.js:72');
  console.log(`✓ Server SIAKAD BM Berjalan di: http://localhost:${PORT} - app.js:73`);
  console.log(`Login Portal   : http://localhost:${PORT}/index.html - app.js:74`);
  console.log(`Dashboard Guru : http://localhost:${PORT}/dashboardguru.html - app.js:75`);
  console.log(`Rapor Santri   : http://localhost:${PORT}/raporsantri.html - app.js:76`);
  console.log('==================================================== - app.js:77');
  require('dotenv').config();
const express = require('express');
const path = require('path');
const cors = require('cors');
const db = require('./src/src/database'); // <-- 1. Import koneksi database

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname)));
app.use('/assets', express.static(path.join(__dirname, 'assets')));

// Rute Halaman
app.get('/', (req, res) => res.sendFile(path.join(__dirname, 'index.html')));
app.get('/dashboard', (req, res) => res.sendFile(path.join(__dirname, 'dashboard-guru.html')));
app.get('/rapor', (req, res) => res.sendFile(path.join(__dirname, 'rapor-santri.html')));

// Jalankan Server & Uji Koneksi Database
app.listen(PORT, async () => {
  console.log('==================================================== - app.js:100');
  console.log(`✓ Server SIAKAD BM aktif di: http://localhost:${PORT} - app.js:101`);

  // 2. Uji apakah MySQL berhasil terhubung
  try {
    const connection = await db.getConnection();
    console.log('✓ Database MySQL "siakad_bm" BERHASIL TERHUBUNG! - app.js:106');
    connection.release();
  } catch (err) {
    console.error('✗ GAGAL TERHUBUNG KE MYSQL: - app.js:109', err.message);
    console.log('Pastikan MySQL di XAMPP/Service lokal Anda sudah dinyalakan (Running). - app.js:110');
  }
  console.log('==================================================== - app.js:112');
});
});
