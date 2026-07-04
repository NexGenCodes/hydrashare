import AxiosService from "../axios.service";
import { CACHE_MANAGER, Inject, Injectable } from "@nestjs/common";
import { TollPurchase, TollPurchaseBulk, VerifyTollNumber } from "./interface";
import { ServiceType } from "../interface";
import { AxiosResponse } from "axios";
import { Cache } from "cache-manager";
import ResponseService from "../response/response.service";

@Injectable()
export default class TollService {
  private type: ServiceType = "TOLL";
  constructor(
    private readonly axiosService: AxiosService,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
    private response: ResponseService
  ) {}

  async purchase(tollPurchase: TollPurchase) {
    try {
      const body = {
        ...tollPurchase,
        biller_name: tollPurchase.type,
        reference: this.axiosService.generateUniqueId(this.type),
      };
      const response = await this.axiosService.request().post("/bills", body);
      return this.response.purchase(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  async purchaseBulk(tollDtoBulk: TollPurchaseBulk) {
    try {
      const bulk = (this.type + "_BULK") as ServiceType;
      const body = {
        ...tollDtoBulk,
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
  async verify(verify: VerifyTollNumber) {
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
          .get(`/bill-categories/?toll=1`);
        await this.cacheService.set(this.type, response);
      }
      return this.response.categories(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
}
