// backend/utils/catchAsync.js
// ============================================================
// ASYNC ERROR WRAPPER — Eliminates try/catch blocks in route handlers.
// Without this, every async route handler would need:
//   exports.myRoute = async (req, res, next) => {
//     try { ... } catch(err) { next(err); }
//   };
//
// With catchAsync, we just write:
//   exports.myRoute = catchAsync(async (req, res, next) => { ... });
// Any thrown error is automatically caught and forwarded to errorHandler.
// ============================================================
module.exports = fn => {
    return (req, res, next) => {
        fn(req, res, next).catch(err => {
            // Assign a default error code if the error doesn't have one
            if (!err.errorCode) {
                err.errorCode = 'BE-GEN-500';
            }
            // Forward to the global error handler middleware
            next(err);
        });
    };
};
