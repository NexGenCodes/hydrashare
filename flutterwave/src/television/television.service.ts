import AxiosService from "../axios.service";
import { CACHE_MANAGER, Inject, Injectable } from "@nestjs/common";
import {
  TV_BILLER_CODES,
  TvProvider,
  TvPurchase,
  TvPurchaseBulk,
  VerifyTvNumber,
} from "./interface";
import { ServiceType } from "../interface";
import { AxiosResponse } from "axios";
import { Cache } from "cache-manager";
import ResponseService from '../response/response.service';
import { Categories } from "../response/interface";

@Injectable()
export default class TelevisionService {
  private type: ServiceType = "TV";
  constructor(
    private readonly axiosService: AxiosService,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
    private response:ResponseService,
  ) {}

  async purchase(tvPurchase: TvPurchase) {
    try {
      const body = {
        ...tvPurchase,
        biller_name: tvPurchase.type,
        reference: this.axiosService.generateUniqueId(this.type),
      };
      const response = await this.axiosService.request().post("/bills", body);
      return this.response.purchase(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  async purchaseBulk(tvPurchaseBulk: TvPurchaseBulk) {
    try {
      const bulk = (this.type + "_BULK") as ServiceType;
      const body = {
        ...tvPurchaseBulk,
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
  async verify(verify: VerifyTvNumber) {
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
  async categories(provider?: TvProvider) {
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

  private async categoriesByProvider(provider: TvProvider) {
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

  private async getBillerCode(provider: TvProvider) {
    let billerCode: string;
    if (provider === "STARTIMES") {
      billerCode = TV_BILLER_CODES["STARTIMES"];
    } else if (provider === "DSTV") {
      billerCode = TV_BILLER_CODES["DSTV"];
    } else if (provider === "GOTV") {
      billerCode = TV_BILLER_CODES["GOTV"];
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
          .get(`/bill-categories/?cable=1`);
        await this.cacheService.set(this.type, response);
      }
      return response;
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
}
