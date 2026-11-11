// src/routes/api.js
const express = require('express');
const router = express.Router();

const auth = require('../controllers/authController');
const attendance = require('../controllers/attendanceController');
const grade = require('../controllers/gradeController');

// 1. Rute Otentikasi
router.post('/auth/register-wali', auth.registerWaliMurid);
router.post('/auth/login', auth.login);

// 2. Rute Presensi
router.post('/attendance/student', attendance.saveStudentAttendance);
router.get('/attendance/teacher/monthly-report', attendance.getTeacherMonthlyReport);

// 3. Rute Nilai & Ranking
router.post('/grades/save', grade.saveGrade);
router.get('/grades/ranking', grade.getClassRanking);

module.exports = router;