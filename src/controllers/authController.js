// src/controllers/authController.js
const db = require('../config/database');

// 1. Registrasi Wali Murid via kode_murid unik (misal: BM-TPA-001)
exports.registerWaliMurid = async (req, res) => {
  const { kode_murid, username, password, nama_wali, nomor_hp } = req.body;

  if (!kode_murid || !username || !password) {
    return res.status(400).json({ success: false, message: 'Kode murid, username, dan password wajib diisi!' });
  }

  try {
    const [studentRows] = await db.query(
      'SELECT id, nama_santri FROM students WHERE kode_murid = ? AND status = "aktif"',
      [kode_murid]
    );

    if (studentRows.length === 0) {
      return res.status(404).json({ success: false, message: 'Kode Murid tidak ditemukan atau santri berstatus nonaktif!' });
    }

    const student = studentRows[0];

    const [userCheck] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
    if (userCheck.length > 0) {
      return res.status(400).json({ success: false, message: 'Username sudah digunakan, silakan pilih username lain!' });
    }

    const [userResult] = await db.query(
      `INSERT INTO users (nama_lengkap, username, password, role, nomor_hp) 
       VALUES (?, ?, ?, 'wali_murid', ?)`,
      [nama_wali || `Wali dari ${student.nama_santri}`, username, password, nomor_hp || null]
    );

    const newUserId = userResult.insertId;

    await db.query(
      `INSERT INTO wali_students (user_id, student_id, hubungan) VALUES (?, ?, 'Orang Tua / Wali')`,
      [newUserId, student.id]
    );

    return res.status(201).json({
      success: true,
      message: `Pendaftaran wali murid berhasil untuk santri: ${student.nama_santri}. Silakan login.`
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// 2. Login Multi-Role (Guru Tugas, Asatid, Honorer, Wali Murid)
exports.login = async (req, res) => {
  const { username, password } = req.body;

  try {
    const [rows] = await db.query(
      'SELECT id, nama_lengkap, username, password, role, foto_profil FROM users WHERE username = ? AND status_aktif = "aktif"',
      [username]
    );

    if (rows.length === 0 || rows[0].password !== password) {
      return res.status(401).json({ success: false, message: 'Username atau kata sandi keliru!' });
    }

    const user = rows[0];
    return res.json({
      success: true,
      message: 'Login berhasil!',
      user: {
        id: user.id,
        nama: user.nama_lengkap,
        username: user.username,
        role: user.role,
        foto_profil: user.foto_profil
      }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};