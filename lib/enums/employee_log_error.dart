enum EmployeeLogError {
  employeeNotFound,
  noActiveSchedule,
  alreadyTimedIn,
  noTimeIn,
  alreadyTimedOut,
  duplicateAux,
  success,
  serverError,
  unknown;

  static EmployeeLogError fromCode(String? code) {
    switch (code) {
      case 'EMPLOYEE_NOT_FOUND':
        return EmployeeLogError.employeeNotFound;
      case 'NO_ACTIVE_SCHEDULE':
        return EmployeeLogError.noActiveSchedule;
      case 'ALREADY_TIMED_IN':
        return EmployeeLogError.alreadyTimedIn;
      case 'NO_TIME_IN':
        return EmployeeLogError.noTimeIn;
      case 'ALREADY_TIMED_OUT':
        return EmployeeLogError.alreadyTimedOut;
      case 'DUPLICATE_AUX':
        return EmployeeLogError.duplicateAux;
      case 'SUCCESS':
        return EmployeeLogError.success;
      case 'SERVER_ERROR':
        return EmployeeLogError.serverError;
      default:
        return EmployeeLogError.unknown;
    }
  }
}
