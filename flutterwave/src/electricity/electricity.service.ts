import AxiosService from "../axios.service";
import { Inject, Injectable, CACHE_MANAGER } from "@nestjs/common";
import {
  ELECT_BILLER_CODES,
  ElectProvider,
  ElectPurchase,
  ElectPurchaseBulk,
  VerifyMeterNumber,
} from "./interface";
import { ServiceType } from "../interface";
import { AxiosResponse } from "axios";
import { Cache } from "cache-manager";
import ResponseService from "../response/response.service";
import { Categories } from "../response/interface";

@Injectable()
export default class ElectricityService {
  private type: ServiceType = "ELECTRICITY";
  constructor(
    private readonly axiosService: AxiosService,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
    private response:ResponseService
  ) {}

  async purchase(electPurchase: ElectPurchase) {
    try {
      const body = {
        ...electPurchase,
        biller_name: electPurchase.type,
        reference: this.axiosService.generateUniqueId(this.type),
      };
      const response = await this.axiosService.request().post("/bills", body);
      return this.response.purchase(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  async purchaseBulk(electPurchaseBulk: ElectPurchaseBulk) {
    try {
      const bulk = (this.type + "_BULK") as ServiceType;
      const body = {
        ...electPurchaseBulk,
        bulk_reference: this.axiosService.generateUniqueId(bulk),
      };
      const response = await this.axiosService
        .request()
        .post("/bulk-bills", body);
      return this.response.purchaseBulk(response, bulk);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
  async verify(verify: VerifyMeterNumber) {
    try {
      const response = await this.axiosService
        .request()
        .get(
          `/bill-items/${verify.item_code}/verify?/code=${verify.biller_code}&customer=${verify.customer}`
        );
      return this.response.verify(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
  async categories(provider?: ElectProvider) {
    try {
      let response: AxiosResponse<Categories>;
      if (provider) {
        response = await this.categoriesByProvider(provider);
      } else {
        response = await this.getCategories();
      }

      return this.response.categories(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  private async categoriesByProvider(provider: ElectProvider) {
    const billerCode = await this.getBillerCode(provider);
    try {
      let response: AxiosResponse;
      const cachedData = await this.cacheService.get<AxiosResponse>(billerCode);
      response = cachedData;
      if (!cachedData) {
        response = await this.axiosService
          .request()
          .get(`/bill-categories/?biller_code=${billerCode}`);
        await this.cacheService.set(billerCode, response);
      }
      return response;
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  private async getBillerCode(provider: ElectProvider) {
    let billerCode: string;
    if (provider === "EEDC") {
      billerCode = ELECT_BILLER_CODES["EEDC"];
    } else if (provider === "EKEDC") {
      billerCode = ELECT_BILLER_CODES["EKEDC"];
    } else if (provider === "IKEDC") {
      billerCode = ELECT_BILLER_CODES["IKEDC"];
    }
    return billerCode;
  }
  private async getCategories() {
    try {
      let response: AxiosResponse;
      const cachedData = await this.cacheService.get<AxiosResponse>(this.type);
      response = cachedData;
      if (!cachedData) {
        response = await this.axiosService
          .request()
          .get(`/bill-categories/?power=1`);
        await this.cacheService.set(this.type, response);
      }
      return response;
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
}
