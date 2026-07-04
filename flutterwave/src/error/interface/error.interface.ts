export type ErrorCodes = 401 | 403 | 404 | 406 | 422 | 503 | number;
export interface ErrorParamType {
    message: string;
    stack?: string;
    code: ErrorCodes;
  }