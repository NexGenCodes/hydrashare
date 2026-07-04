import { CACHE_MANAGER, Injectable, Inject } from "@nestjs/common";
import { ServiceType } from "../interface";
import AxiosService from "../axios.service";
import { AxiosResponse } from "axios";
import { Cache } from "cache-manager";
import ResponseService from "../response/response.service";

@Injectable()
export default class MiscellaneousService {
  private type: ServiceType = "MISC";
  constructor(
    private axiosService: AxiosService,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
    private response: ResponseService
  ) {}
  async categories() {
    try {
      let response: AxiosResponse;
      const cachedData = await this.cacheService.get<AxiosResponse>(this.type);
      response = cachedData;
      if (!cachedData) {
        response = await this.axiosService.request().get(`/bill-categories/`);
      }
      return this.response.categories(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
  async billStatus(reference: string) {
    try {
      const response = await this.axiosService
        .request()
        .get(`/bills/${reference}`);

      return this.response.billStatus(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
}
