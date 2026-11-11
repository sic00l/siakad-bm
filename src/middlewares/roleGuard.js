// src/middlewares/roleGuard.js
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