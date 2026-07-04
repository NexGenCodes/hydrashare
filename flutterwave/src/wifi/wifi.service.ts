import AxiosService from "../axios.service";
import { CACHE_MANAGER, Inject, Injectable } from "@nestjs/common";
import {
  WifiProvider,
  WifiPurchase,
  WifiPurchaseBulk,
  VerifyWifiNumber,
  WIFI_BILLER_CODES,
} from "./interface";
import { ServiceType } from "../interface";
import { AxiosResponse } from "axios";
import { Cache } from "cache-manager";
import ResponseService from "../response/response.service";
import { Categories } from "../response/interface";

@Injectable()
export default class WifiService {
  private type: ServiceType = "WIFI";
  constructor(
    private readonly axiosService: AxiosService,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
    private response:ResponseService
  ) {}

  async purchase(wifiPurchase: WifiPurchase) {
    try {
      const body = {
        ...wifiPurchase,
        biller_name: wifiPurchase.type,
        reference: this.axiosService.generateUniqueId(this.type),
      };
      const response = await this.axiosService.request().post("/bills", body);
      return this.response.purchase(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  async purchaseBulk(wifiPurchaseBulk: WifiPurchaseBulk) {
    try {
      const bulk = (this.type + "_BULK") as ServiceType;
      const body = {
        ...wifiPurchaseBulk,
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
  async verify(verify: VerifyWifiNumber) {
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
  async categories(provider?: WifiProvider) {
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

  private async categoriesByProvider(provider: WifiProvider) {
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

  private async getBillerCode(provider: WifiProvider) {
    let billerCode: string;
    if (provider === "SMILE") {
      billerCode = WIFI_BILLER_CODES["SMILE"];
    } else if (provider === "SPECTRANET") {
      billerCode = WIFI_BILLER_CODES["SPECTRANET"];
    } else if (provider === "SWIFT") {
      billerCode = WIFI_BILLER_CODES["SWIFT"];
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
          .get(`/bill-categories/?internet=1`);
        await this.cacheService.set(this.type, response);
      }
      return response;
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
}
