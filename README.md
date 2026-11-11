=====================================================================

ARSITEKTUR BACKEND & API ROUTES / CONTROLLER

APLIKASI: SIAKAD BUSTANUL MUSTAFIDIN (SIAKAD BM)

Stack: Node.js (Express.js) + MySQL2 / Knex / Sequelize

=====================================================================

Struktur Folder Proyek Rekomendasi di VS Code

siakad-bm/
├── src/
│   ├── config/
│   │   └── database.js         # Koneksi Pool MySQL
│   ├── middlewares/
│   │   ├── authMiddleware.js   # Verifikasi Token JWT & Session
│   │   ├── roleGuard.js        # RBAC 4 Role (Guru Tugas, Asatid, Honorer, Wali Murid)
│   │   └── scheduleGuard.js    # Validasi Jadwal Mengajar Asatidz
│   ├── controllers/
│   │   ├── authController.js       # Login, Register Wali via Kode Murid, Ubah Sandi
│   │   ├── studentController.js    # CRUD Data Santri TPA & MD
│   │   ├── attendanceController.js # Absensi Murid & Absensi Guru Harian
│   │   ├── gradeController.js      # Input Nilai Mapel & Override Guru Tugas
│   │   └── pdfReportController.js  # Cetak Rapor Resmi TTD H. Moh. Bahwi & Ust. Subahri
│   ├── routes/
│   │   ├── api.js              # Definisi Endpoint API Lengkap
│   │   └── index.js
│   └── app.js                  # Entrypoint Express Server
├── .env
├── package.json
└── README.md


Memproteksi rute endpoint berdasarkan role pengguna.

const allowRoles = (...allowedRoles) => {
return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
    return res.status(403).json({
        success: false,
        message: 'Akses ditolak! Anda tidak memiliki izin untuk tindakan ini.'
    });
    }
    next();
};
};

module.exports = { allowRoles };


Validasi ketat jadwal Asatid: Pengajar hanya bisa absen jika hari ini sesuai jadwal mengajarnya. Guru Tugas memiliki bypass akses.

const db = require('../config/database');

const checkTeachingSchedule = async (req, res, next) => {
const user = req.user;
if (user.role === 'guru_tugas') {
    return next();
}
if (user.role === 'asatid') {
    const { jenjang, kelas } = req.body;
    const daysMap = ['Ahad', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
    const today = daysMap[new Date().getDay()];

    try {
    const [schedules] = await db.query(
        `SELECT id FROM teaching_schedules
        WHERE guru_id = ? AND hari = ? AND jenjang = ? AND kelas = ?`,
        [user.id, today, jenjang, kelas]
    );

    if (schedules.length === 0) {
        return res.status(403).json({
        success: false,
        message: `Ditolak! Anda hanya diizinkan mengabsen kelas ${jenjang} - ${kelas} pada jadwal hari mengajar Anda (${today}).`
        });
    }

    next();
    } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
    }
} else {
    return res.status(403).json({ success: false, message: 'Role tidak memiliki hak absen murid.' });
}
};

module.exports = { checkTeachingSchedule };

Otentikasi, registrasi akun wali murid via kode_murid, dan ubah profil/password.

const db = require('../config/database');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');

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
    return res.status(404).json({ success: false, message: 'Kode Murid tidak ditemukan atau santri nonaktif!' });
    }

    const student = studentRows[0];

    const [userCheck] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
    if (userCheck.length > 0) {
    return res.status(400).json({ success: false, message: 'Username sudah digunakan, silakan pilih yang lain!' });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    const [userResult] = await db.query(
    `INSERT INTO users (nama_lengkap, username, password, role, nomor_hp) 
    VALUES (?, ?, ?, 'wali_murid', ?)`,
    [nama_wali || `Wali dari ${student.nama_santri}`, username, hashedPassword, nomor_hp || null]
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

exports.login = async (req, res) => {
const { username, password } = req.body;

try {
    const [rows] = await db.query('SELECT * FROM users WHERE username = ? AND status_aktif = "aktif"', [username]);
    if (rows.length === 0) {
    return res.status(401).json({ success: false, message: 'Username atau password salah!' });
    }

    const user = rows[0];
    const isPasswordValid = await bcrypt.compare(password, user.password);
    if (!isPasswordValid) {
    return res.status(401).json({ success: false, message: 'Username atau password salah!' });
    }

    const token = jwt.sign(
    { id: user.id, username: user.username, role: user.role, nama_lengkap: user.nama_lengkap },
    process.env.JWT_SECRET || 'SECRET_KEY_SIAKAD_BM_2026',
    { expiresIn: '7d' }
    );

    return res.json({
    success: true,
    message: 'Login berhasil!',
    token,
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

exports.updatePassword = async (req, res) => {
const { oldPassword, newPassword } = req.body;
const userId = req.user.id;

try {
    const [rows] = await db.query('SELECT password FROM users WHERE id = ?', [userId]);
    const isValid = await bcrypt.compare(oldPassword, rows[0].password);
    if (!isValid) {
    return res.status(400).json({ success: false, message: 'Password lama salah!' });
    }

    const newHashed = await bcrypt.hash(newPassword, 10);
    await db.query('UPDATE users SET password = ? WHERE id = ?', [newHashed, userId]);

    return res.json({ success: true, message: 'Password berhasil diperbarui!' });
} catch (err) {
    return res.status(500).json({ success: false, message: err.message });
}
};

Absensi Murid (Guru Tugas & Asatid sesuai jadwal) dan Absensi Guru (oleh Guru Tugas, dipantau Honorer).

const db = require('../config/database');

exports.saveStudentAttendance = async (req, res) => {
const { tanggal, jenjang, kelas, attendances } = req.body;
const recordedBy = req.user.id;

try {
    for (const att of attendances) {
    await db.query(
        `INSERT INTO attendance_students (student_id, tanggal, jenjang, kelas, status, keterangan, recorded_by)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE status = VALUES(status), keterangan = VALUES(keterangan), recorded_by = VALUES(recorded_by)`,
        [att.student_id, tanggal, jenjang, kelas, att.status, att.keterangan || null, recordedBy]
    );
    }

    return res.json({ success: true, message: 'Presensi santri berhasil disimpan!' });
} catch (err) {
    return res.status(500).json({ success: false, message: err.message });
}
};
exports.recordTeacherAttendance = async (req, res) => {
const { guru_id, tanggal, status, keterangan } = req.body;
const guruTugasId = req.user.id;

try {
    await db.query(
    `INSERT INTO attendance_teachers (guru_id, tanggal, status, keterangan, input_by_guru_tugas)
    VALUES (?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE status = VALUES(status), keterangan = VALUES(keterangan), input_by_guru_tugas = VALUES(input_by_guru_tugas)`,
    [guru_id, tanggal, status, keterangan || null, guruTugasId]
    );

    return res.json({ success: true, message: 'Kehadiran asatidz berhasil dicatat!' });
} catch (err) {
    return res.status(500).json({ success: false, message: err.message });
}
};

exports.getTeacherMonthlyReport = async (req, res) => {
const { bulan, tahun } = req.query;

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

Input nilai mapel (Asatid sesuai mapel) & Override Nilai oleh Guru Tugas.

const db = require('../config/database');

exports.saveGrade = async (req, res) => {
const { student_id, subject_id, jenjang, kelas, periode, tahun_ajaran, nilai_angka, catatan } = req.body;
const user = req.user;

try {
    if (user.role === 'asatid') {
    const [scheduleCheck] = await db.query(
        `SELECT id FROM teaching_schedules
        WHERE guru_id = ? AND subject_id = ? AND jenjang = ? AND kelas = ?`,
        [user.id, subject_id, jenjang, kelas]
    );

    if (scheduleCheck.length === 0) {
        return res.status(403).json({
        success: false,
        message: 'Ditolak! Anda bukan pengampu mata pelajaran atau kelas ini.'
        });
    }
    }

    await db.query(
    `INSERT INTO grades
    (student_id, subject_id, jenjang, kelas, periode, tahun_ajaran, nilai_angka, input_by_user_id, catatan)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON DUPLICATE KEY UPDATE
        nilai_angka = VALUES(nilai_angka),
        last_updated_by = ?,
        catatan = VALUES(catatan)`,
    [student_id, subject_id, jenjang, kelas, periode, tahun_ajaran, nilai_angka, user.id, catatan || null, user.id]
    );

    return res.json({ success: true, message: 'Nilai santri berhasil disimpan!' });
} catch (err) {
    return res.status(500).json({ success: false, message: err.message });
}
};

exports.getClassRanking = async (req, res) => {
const { jenjang, kelas, periode, tahun_ajaran } = req.query;

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

Router sentral memetakan endpoint dan RBAC guard.

const express = require('express');
const router = express.Router();

const { allowRoles } = require('../middlewares/roleGuard');
const { checkTeachingSchedule } = require('../middlewares/scheduleGuard');

const auth = require('../controllers/authController');
const attendance = require('../controllers/attendanceController');
const grade = require('../controllers/gradeController');

router.post('/auth/register-wali', auth.registerWaliMurid);
router.post('/auth/login', auth.login);
router.put('/auth/update-password', auth.updatePassword);

router.post('/attendance/student', allowRoles('guru_tugas', 'asatid'), checkTeachingSchedule, attendance.saveStudentAttendance);

router.post('/attendance/teacher', allowRoles('guru_tugas'), attendance.recordTeacherAttendance);

router.get('/attendance/teacher/monthly-report', allowRoles('guru_tugas', 'honorer'), attendance.getTeacherMonthlyReport);

router.post('/grades/save', allowRoles('guru_tugas', 'asatid'), grade.saveGrade);

router.get('/grades/ranking', allowRoles('guru_tugas', 'asatid', 'wali_murid'), grade.getClassRanking);

module.exports = router;

