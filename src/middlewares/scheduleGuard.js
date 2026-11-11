// src/middlewares/scheduleGuard.js
const db = require('../config/database');

const checkTeachingSchedule = async (req, res, next) => {
  const user = req.user;
  
  // Guru Tugas memiliki akses bypass untuk seluruh kelas
  if (user && user.role === 'guru_tugas') {
    return next();
  }

  if (user && user.role === 'asatid') {
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
    // Untuk tahap pengujian awal (jika belum ada session login), izinkan lewat
    next();
  }
};

module.exports = { checkTeachingSchedule };