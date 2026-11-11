// src/controllers/gradeController.js
const db = require('../config/database');

// 1. Simpan Nilai Santri
exports.saveGrade = async (req, res) => {
  const { student_id, subject_id, jenjang, kelas, periode, tahun_ajaran = '2025/2026', nilai_angka, catatan } = req.body;
  const userId = req.user ? req.user.id : 1;

  try {
    await db.query(
      `INSERT INTO grades 
       (student_id, subject_id, jenjang, kelas, periode, tahun_ajaran, nilai_angka, input_by_user_id, catatan)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE 
         nilai_angka = VALUES(nilai_angka),
         last_updated_by = ?,
         catatan = VALUES(catatan)`,
      [student_id, subject_id, jenjang, kelas, periode, tahun_ajaran, nilai_angka, userId, catatan || null, userId]
    );

    return res.json({ success: true, message: 'Nilai santri berhasil disimpan ke database!' });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};

// 2. Ranking Leger Kelas (Peringkat 1 s.d. 100)
exports.getClassRanking = async (req, res) => {
  const { jenjang = 'TPA', kelas = 'A', periode = 'Evaluasi 1', tahun_ajaran = '2025/2026' } = req.query;

  try {
    const [rows] = await db.query(
      `SELECT s.id AS student_id, s.kode_murid, s.nama_santri,
              SUM(g.nilai_angka) AS total_nilai,
              ROUND(AVG(g.nilai_angka), 2) AS rata_rata,
              DENSE_RANK() OVER (ORDER BY AVG(g.nilai_angka) DESC) AS ranking
       FROM students s
       JOIN grades g ON s.id = g.student_id
       WHERE g.jenjang = ? AND g.kelas = ? AND g.periode = ? AND g.tahun_ajaran = ?
       GROUP BY s.id, s.kode_murid, s.nama_santri
       ORDER BY ranking ASC
       LIMIT 100`,
      [jenjang, kelas, periode, tahun_ajaran]
    );

    return res.json({ success: true, data: rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};