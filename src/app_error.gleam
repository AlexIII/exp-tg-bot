pub type AppError {
  AppError(message: String)
  DbError(message: String)
  InvalidCurrency(message: String)
  InvalidMessageFormat(message: String)
  ApiError(message: String)
  ConfigMissing(message: String)
}
