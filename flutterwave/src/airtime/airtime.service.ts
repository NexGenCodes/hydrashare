import AxiosService from "../axios.service";
import { CACHE_MANAGER, Inject, Injectable } from "@nestjs/common";
import { Cache } from "cache-manager";
import {
  AirtimePurchase,
  AirtimePurchaseBulk,
  VerifyAirtimeNumber,
} from "./interface";
import { ServiceType } from "../interface";
import { AxiosResponse } from "axios";
import ResponseService from "../response/response.service";

@Injectable()
export default class AirtimeService {
  private type: ServiceType = "AIRTIME";
  constructor(
    private readonly axiosService: AxiosService,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
    private response: ResponseService
  ) {}

  async purchase(airtimePurchase: AirtimePurchase) {
    try {
      const body = {
        ...airtimePurchase,
        biller_name: airtimePurchase.type,
        reference: this.axiosService.generateUniqueId(this.type),
      };
      const response = await this.axiosService.request().post("/bills", body);
      return this.response.purchase(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  async purchaseBulk(airtimeDtoBulk: AirtimePurchaseBulk) {
    try {
      const bulk = (this.type + "_BULK") as ServiceType;
      const body = {
        ...airtimeDtoBulk,
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
  async verify(verify: VerifyAirtimeNumber) {
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
  async categories() {
    try {
      let response: AxiosResponse;
      const cachedData = await this.cacheService.get<AxiosResponse>(this.type);
      response = cachedData;
      if (!cachedData) {
        response = await this.axiosService
          .request()
          .get(`/bill-categories/?airtime=1`);
        await this.cacheService.set(this.type, response);
      }
      return this.response.categories(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
}
