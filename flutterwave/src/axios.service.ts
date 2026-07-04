import { Inject, Injectable } from "@nestjs/common";
import axios, { AxiosError } from "axios";
import { randomBytes } from "crypto";
import { MODULE_OPTIONS_TOKEN, ModuleOptions, ServiceType } from "./interface";
import { BaseError } from "./error/error.service";
import { ErrorCodes } from "./error/interface";

@Injectable()
export default class AxiosService {
  constructor(@Inject(MODULE_OPTIONS_TOKEN) private options: ModuleOptions) {}

  generateUniqueId(type: ServiceType) {
    return `${randomBytes(10).toString("hex")}${type}`;
  }

  private getAuth() {
    return `bearer ${this.options.SECRET_KEY}`;
  }

  request() {
    return axios.create({
      baseURL: "https://api.flutterwave.com/v3/",
      headers: {
        "Content-Type": "application/json",
        Authorization: this.getAuth(),
      },
    });
  }

  handleError(error: any) {
    if (error.isAxiosError === true) {
      this.EmitError(error as AxiosError);
    } else {
      throw new Error(`${error} internal server error`);
    }
  }

  private EmitError(error: AxiosError) {
    const code = error?.response?.status as ErrorCodes;
    const message = (error.response.data as string) || error.message;
    const stack = error.stack;
    new BaseError({
      code,
      stack,
      message,
    });
  }
}
