// src/controllers/attendanceController.js
const db = require('../config/database');

// 1. Simpan Presensi Santri Harian
exports.saveStudentAttendance = async (req, res) => {
  const { tanggal, jenjang, kelas, attendances } = req.body; 
  const recordedBy = req.user ? req.user.id : 1; // default ke admin jika sesi lokal

  try {
    if (Array.isArray(attendances)) {
      for (const att of attendances) {
        await db.query(
          `INSERT INTO attendance_students (student_id, tanggal, jenjang, kelas, status, keterangan, recorded_by)
           VALUES (?, ?, ?, ?, ?, ?, ?)
           ON DUPLICATE KEY UPDATE status = VALUES(status), keterangan = VALUES(keterangan), recorded_by = VALUES(recorded_by)`,
          [att.student_id, tanggal, jenjang, kelas, att.status, att.keterangan || null, recordedBy]
        );
      }
    }

    return res.json({ success: true, message: 'Presensi santri berhasil disimpan ke database!' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// 2. Rekap Bulanan Masuk Guru (Untuk Guru Tugas & Honorer)
exports.getTeacherMonthlyReport = async (req, res) => {
  const { bulan = new Date().getMonth() + 1, tahun = new Date().getFullYear() } = req.query;

  try {
    const [rows] = await db.query(
      `SELECT u.id, u.nama_lengkap,
              SUM(CASE WHEN a.status = 'Hadir' THEN 1 ELSE 0 END) AS total_hadir,
              SUM(CASE WHEN a.status = 'Izin' THEN 1 ELSE 0 END) AS total_izin,
              SUM(CASE WHEN a.status = 'Sakit' THEN 1 ELSE 0 END) AS total_sakit,
              SUM(CASE WHEN a.status = 'Alpa' THEN 1 ELSE 0 END) AS total_alpa
       FROM users u
       LEFT JOIN attendance_teachers a 
         ON u.id = a.guru_id 
         AND MONTH(a.tanggal) = ? AND YEAR(a.tanggal) = ?
       WHERE u.role IN ('asatid', 'guru_tugas') AND u.status_aktif = 'aktif'
       GROUP BY u.id, u.nama_lengkap
       ORDER BY u.nama_lengkap ASC`,
      [bulan, tahun]
    );

    return res.json({ success: true, data: rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};