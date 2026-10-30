"""Application error hierarchy. Each error maps to a process exit code."""


class AppError(Exception):
    exit_code = 1

    def __init__(self, message: str, exit_code: int | None = None) -> None:
        super().__init__(message)
        if exit_code is not None:
            self.exit_code = exit_code


class ValidationError(AppError):
    exit_code = 2


class NotFoundError(AppError):
    exit_code = 3


class ConflictError(AppError):
    exit_code = 4
