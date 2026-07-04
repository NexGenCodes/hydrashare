import AxiosService from "../axios.service";
import { CACHE_MANAGER, Inject, Injectable } from "@nestjs/common";
import {
  DATA_BILLER_CODES,
  DataProvider,
  DataPurchase,
  DataPurchaseBulk,
  VerifyDataNumber,
} from "./interface";
import { ServiceType } from "../interface";
import { AxiosResponse } from "axios";
import { Cache } from "cache-manager";
import ResponseService from "../response/response.service";
import { Categories } from "../response/interface";

@Injectable()
export default class DataService {
  private type: ServiceType = "DATA";
  constructor(
    private readonly axiosService: AxiosService,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
    private response:ResponseService,
  ) {}

  async purchase(dataPurchase: DataPurchase) {
    try {
      const body = {
        ...dataPurchase,
        biller_name: dataPurchase.type,
        reference: this.axiosService.generateUniqueId(this.type),
      };
      const response = await this.axiosService.request().post("/bills", body);
      return this.response.purchase(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  async purchaseBulk(dataPurchaseBulk: DataPurchaseBulk) {
    try {
      const bulk = (this.type + "_BULK") as ServiceType;
      const body = {
        ...dataPurchaseBulk,
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
  async verify(verify: VerifyDataNumber) {
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
  async categories(network?: DataProvider) {
    try {
      let response: AxiosResponse<Categories>;
      if (network) {
        response = await this.categoriesByProvider(network);
      } else {
        response = await this.getCategories();
      }

      return this.response.categories(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  private async categoriesByProvider(network: DataProvider) {
    const billerCode = await this.getBillerCode(network);
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

  private async getBillerCode(network: DataProvider) {
    let billerCode: string;
    if (network === "MTN") {
      billerCode = DATA_BILLER_CODES["MTN"];
    } else if (network === "GLO") {
      billerCode = DATA_BILLER_CODES["GLO"];
    } else if (network === "AIRTEL") {
      billerCode = DATA_BILLER_CODES["AIRTEL"];
    } else if (network === "9MOBILE") {
      billerCode = DATA_BILLER_CODES["9MOBILE"];
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
          .get(`/bill-categories/?data_bundle=1`);
        await this.cacheService.set(this.type, response);
      }
      return response;
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
}
