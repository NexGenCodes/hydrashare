import { ErrorCodes, ErrorParamType } from "./interface";

export class BaseError extends Error {
  constructor(options: ErrorParamType) {
    super();
    this.name = this.getName(options.code);
    this.stack = options.stack;
    this.message = options.message;
  }

 

  private getName(code: ErrorCodes) {
    let name: string;
    if (code === 401) {
      name = "UnauthorizedError";
    } else if (code === 403) {
      name = "ForbiddenError";
    } else if (code === 404) {
      name = "InvalidResourceError";
    } else if (code === 406) {
      name = "NotAcceptableError";
    } else if (code === 422) {
      name = "InvalidPayloadError";
    } else if (code === 503) {
      name = "ServiceUnavailableError";
    } else {
      name = "ServerError";
    }
    return name;
  }
}
