-- =====================================================================
-- DATABASE MIGRATION / DDL SQL (TERKOREKSI & 100% SESUAI KETENTUAN)
-- APLIKASI: SIAKAD BUSTANUL MUSTAFIDIN (SIAKAD BM)
-- Target DBMS: MySQL 8.0+ / MariaDB 10.4+
-- Terintegrasi: RBAC 4 Role, Jenjang TPA & MD, Jadwal Asatidz, Presensi & Nilai
-- =====================================================================

-- 1. Inisialisasi Database
CREATE DATABASE IF NOT EXISTS siakad_bm 
CHARACTER SET utf8mb4 
COLLATE utf8mb4_unicode_ci;

USE siakad_bm;

-- Nonaktifkan pengecekan foreign key sementara agar pembuatan tabel lancar
SET FOREIGN_KEY_CHECKS = 0;



-- TABEL 1: USERS (PENGGUNA & RBAC)
-- Menyimpan kredensial untuk Guru Tugas, Asatid, Honorer, dan Wali Murid



DROP TABLE IF EXISTS users;
CREATE TABLE users (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  nama_lengkap VARCHAR(100) NOT NULL,
  username VARCHAR(50) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL COMMENT 'Bcrypt / Argon2 hash password',
  role ENUM('guru_tugas', 'asatid', 'honorer', 'wali_murid') NOT NULL DEFAULT 'wali_murid',
  nomor_hp VARCHAR(20) NULL,
  foto_profil VARCHAR(255) NULL DEFAULT 'default-avatar.png',
  status_aktif ENUM('aktif', 'nonaktif') NOT NULL DEFAULT 'aktif',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_role (role),
  INDEX idx_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- TABEL 2: STUDENTS (MASTER DATA SANTRI / MURID)
-- Menyimpan data santri TPA & MD serta kode_murid unik untuk registrasi wali murid



DROP TABLE IF EXISTS students;
CREATE TABLE students (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  kode_murid VARCHAR(30) NOT NULL UNIQUE COMMENT 'Kode unik/NIS santri untuk klaim akun wali murid',
  nama_santri VARCHAR(100) NOT NULL,
  jenis_kelamin ENUM('L', 'P') NOT NULL,
  jenjang ENUM('TPA', 'MD') NOT NULL COMMENT 'TPA: Taman Pendidikan Al-Quran, MD: Madrasah Diniyah',
  kelas VARCHAR(20) NOT NULL COMMENT 'Untuk TPA: A, B, C, Intensif | Untuk MD: 1, 2, 3, 4, 5',
  tahun_masuk YEAR NOT NULL DEFAULT (YEAR(CURRENT_DATE)),
  nama_wali VARCHAR(100) NULL,
  alamat TEXT NULL,
  status ENUM('aktif', 'lulus', 'berhenti') NOT NULL DEFAULT 'aktif',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_jenjang_kelas (jenjang, kelas),
  INDEX idx_status (status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- TABEL 3: WALI_STUDENTS (RELASI AKUN WALI MURID DENGAN SANTRI)
-- Memetakan user_id (role wali_murid) dengan santri yang didaftarkan via kode_murid



DROP TABLE IF EXISTS wali_students;
CREATE TABLE wali_students (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  user_id INT UNSIGNED NOT NULL,
  student_id INT UNSIGNED NOT NULL,
  hubungan VARCHAR(50) DEFAULT 'Orang Tua / Wali',
  registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uk_wali_student (user_id, student_id),
  CONSTRAINT fk_wali_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_wali_student FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- TABEL 4: SUBJECTS (MASTER MATA PELAJARAN)
-- Daftar mata pelajaran berdasarkan kurikulum TPA dan MD



DROP TABLE IF EXISTS subjects;
CREATE TABLE subjects (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  kode_mapel VARCHAR(30) NOT NULL UNIQUE,
  nama_mapel VARCHAR(100) NOT NULL,
  jenjang ENUM('TPA', 'MD') NOT NULL,
  keterangan VARCHAR(150) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- TABEL 5: TEACHING_SCHEDULES (JADWAL MENGAJAR ASATIDZ)
-- Menjadi acuan validasi sistem: Asatid hanya boleh absen & input nilai sesuai jadwal



DROP TABLE IF EXISTS teaching_schedules;
CREATE TABLE teaching_schedules (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  guru_id INT UNSIGNED NOT NULL COMMENT 'Relasi ke users dengan role asatid / guru_tugas',
  subject_id INT UNSIGNED NOT NULL,
  jenjang ENUM('TPA', 'MD') NOT NULL,
  kelas VARCHAR(20) NOT NULL,
  hari ENUM('Ahad', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu') NOT NULL,
  jam_mulai TIME NULL,
  jam_selesai TIME NULL,
  tahun_ajaran VARCHAR(15) NOT NULL DEFAULT '2025/2026',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT fk_schedule_guru FOREIGN KEY (guru_id) REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_schedule_subject FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_validasi_mengajar (guru_id, hari, jenjang, kelas)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- TABEL 6: ATTENDANCE_STUDENTS (PRESENSI MURID HARIAN)
-- Diisi oleh Asatidz (sesuai jadwal) atau Guru Tugas (kapan saja)



DROP TABLE IF EXISTS attendance_students;
CREATE TABLE attendance_students (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id INT UNSIGNED NOT NULL,
  tanggal DATE NOT NULL,
  jenjang ENUM('TPA', 'MD') NOT NULL,
  kelas VARCHAR(20) NOT NULL,
  status ENUM('H', 'I', 'S', 'A') NOT NULL DEFAULT 'H' COMMENT 'H: Hadir, I: Izin, S: Sakit, A: Alpa',
  keterangan VARCHAR(255) NULL,
  recorded_by INT UNSIGNED NOT NULL COMMENT 'User ID yang menginput presensi',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_student_daily_attendance (student_id, tanggal),
  CONSTRAINT fk_att_student FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_att_recorded_by FOREIGN KEY (recorded_by) REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_tanggal_kelas (tanggal, jenjang, kelas)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- TABEL 7: ATTENDANCE_TEACHERS (PRESENSI KEHADIRAN GURU)
-- Diabsen setiap hari oleh Guru Tugas, dipantau & dicetak PDF oleh Honorer



DROP TABLE IF EXISTS attendance_teachers;
CREATE TABLE attendance_teachers (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  guru_id INT UNSIGNED NOT NULL COMMENT 'User ID asatidz/guru',
  tanggal DATE NOT NULL,
  status ENUM('Hadir', 'Izin', 'Sakit', 'Alpa') NOT NULL DEFAULT 'Hadir',
  jam_kehadiran TIME NULL,
  keterangan VARCHAR(255) NULL,
  input_by_guru_tugas INT UNSIGNED NOT NULL COMMENT 'User ID guru tugas yang bertugas mencatat',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_teacher_daily_attendance (guru_id, tanggal),
  CONSTRAINT fk_att_teacher FOREIGN KEY (guru_id) REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_att_admin FOREIGN KEY (input_by_guru_tugas) REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_bulan_guru (guru_id, tanggal)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- TABEL 8: GRADES (NILAI EVALUASI TPA & SEMESTER MD)
-- Asatidz hanya isi mapelnya; Guru Tugas punya hak override koreksi semua nilai



DROP TABLE IF EXISTS grades;
CREATE TABLE grades (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id INT UNSIGNED NOT NULL,
  subject_id INT UNSIGNED NOT NULL,
  jenjang ENUM('TPA', 'MD') NOT NULL,
  kelas VARCHAR(20) NOT NULL,
  periode ENUM('Evaluasi 1', 'Evaluasi 2', 'Evaluasi 3', 'Semester 1', 'Semester 2') NOT NULL,
  tahun_ajaran VARCHAR(15) NOT NULL DEFAULT '2025/2026',
  nilai_angka DECIMAL(5,2) NOT NULL,
  input_by_user_id INT UNSIGNED NOT NULL COMMENT 'User yang pertama menginput',
  last_updated_by INT UNSIGNED NULL COMMENT 'Bila diedit/dioverride oleh Guru Tugas',
  catatan VARCHAR(255) NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_student_grade_subject (student_id, subject_id, periode, tahun_ajaran),
  CONSTRAINT fk_grade_student FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_grade_subject FOREIGN KEY (subject_id) REFERENCES subjects (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_grade_input_by FOREIGN KEY (input_by_user_id) REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_grade_updated_by FOREIGN KEY (last_updated_by) REFERENCES users (id) ON DELETE RESTRICT ON UPDATE CASCADE,
  INDEX idx_ranking_calc (jenjang, kelas, periode, tahun_ajaran, nilai_angka)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



-- TABEL 9: RAPOR_METADATA (CATATAN & LEGALISASI RAPOR)
-- Data penandatanganan resmi (H. Moh. Bahwi & Ust. Subahri) serta catatan wali kelas



DROP TABLE IF EXISTS rapor_metadata;
CREATE TABLE rapor_metadata (
  id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  student_id INT UNSIGNED NOT NULL,
  periode ENUM('Evaluasi 1', 'Evaluasi 2', 'Evaluasi 3', 'Semester 1', 'Semester 2') NOT NULL,
  tahun_ajaran VARCHAR(15) NOT NULL DEFAULT '2025/2026',
  total_nilai DECIMAL(7,2) DEFAULT 0.00,
  rata_rata DECIMAL(5,2) DEFAULT 0.00,
  peringkat_kelas INT UNSIGNED NULL,
  catatan_wali_kelas TEXT NULL,
  nama_ketua_yayasan VARCHAR(100) NOT NULL DEFAULT 'H. Moh. Bahwi',
  nama_kepala_madrasah VARCHAR(100) NOT NULL DEFAULT 'Ust. Subahri',
  tanggal_cetak DATE NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uk_rapor_student (student_id, periode, tahun_ajaran),
  CONSTRAINT fk_rapor_student FOREIGN KEY (student_id) REFERENCES students (id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Aktifkan kembali pengecekan foreign key
SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- SEED DATA AWAL (BERDASARKAN DATA REKAP RESMI BUSTANUL MUSTAFIDZIN)
-- =====================================================================

-- 1. User Akun Default
INSERT INTO users (id, nama_lengkap, username, password, role) VALUES
(1, 'Guru Tugas (Administrator)', 'gurutugas', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'guru_tugas'),
(2, 'Ust. Subahri (Kepala Madrasah)', 'subahri', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'asatid'),
(3, 'Ustd. Yuni', 'yuni', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'asatid'),
(4, 'Staf Honorer Pemantau', 'honorer', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi', 'honorer');

-- 2. Sampel Santri TPA Kelas A & MD Kelas 1
INSERT INTO students (id, kode_murid, nama_santri, jenis_kelamin, jenjang, kelas, tahun_masuk) VALUES
(1, 'BM-TPA-001', 'A'la Ayana Yasin', 'P', 'TPA', 'A', 2025),
(2, 'BM-TPA-002', 'Zara Almaira Rahman', 'P', 'TPA', 'A', 2025),
(3, 'BM-TPA-003', 'Isbat Samlan', 'L', 'TPA', 'A', 2025),
(4, 'BM-MD-101', 'Azmia', 'P', 'MD', '1', 2025),
(5, 'BM-MD-102', 'Fara', 'P', 'MD', '1', 2025),
(6, 'BM-MD-103', 'Yusron', 'L', 'MD', '1', 2025);

-- 3. Sampel Mata Pelajaran Sesuai Rekap Excel
INSERT INTO subjects (id, kode_mapel, nama_mapel, jenjang) VALUES
(1, 'TPA-TZL', 'At-Tanzil', 'TPA'),
(2, 'TPA-AKH', 'Akhlak', 'TPA'),
(3, 'TPA-MOT', 'Motorik', 'TPA'),
(4, 'TPA-QUR', 'Al-Qur'an', 'TPA'),
(5, 'TPA-THD', 'Tauhid', 'TPA'),
(6, 'TPA-FQH', 'Fiqih', 'TPA'),
(7, 'TPA-BHS', 'Bahasa', 'TPA'),
(8, 'TPA-KRE', 'Kreativitas', 'TPA'),
(9, 'TPA-ASH', 'Asmaul Husna', 'TPA'),
(10, 'MD-FIQ1', 'Fiqih', 'MD'),
(11, 'MD-ARB1', 'Bahasa Arab', 'MD'),
(12, 'MD-TAJ1', 'Tajwid', 'MD'),
(13, 'MD-PRP1', 'Parpesan', 'MD'),
(14, 'MD-SHL1', 'Kaifiyatus Sholah', 'MD');