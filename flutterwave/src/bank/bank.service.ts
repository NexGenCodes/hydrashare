import { CACHE_MANAGER, Inject, Injectable } from "@nestjs/common";
import AxiosService from "../axios.service";
import { Country, ServiceType } from "../interface";
import { AxiosResponse } from "axios";
import { Cache } from "cache-manager";
import {
  Transfer,
  TransferBulk,
  TransferFees,
  TransferRate,
} from "./interface";
import ResponseService from "../response/response.service";

@Injectable()
export default class BankService {
  private type: ServiceType = "BANK";
  constructor(
    private axiosService: AxiosService,
    @Inject(CACHE_MANAGER) private cacheService: Cache,
    private response: ResponseService
  ) {}
  async banks(country: Country) {
    try {
      let response: AxiosResponse;
      const cachedData = await this.cacheService.get<AxiosResponse>(this.type);
      response = cachedData;
      if (!cachedData) {
        response = await this.axiosService.request().get(`/bank/${country}`);
        await this.cacheService.set(this.type, response);
      }
      return this.response.banks(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
  async branches(id: string) {
    try {
      let response: AxiosResponse;
      const cachedData = await this.cacheService.get<AxiosResponse>(id);
      response = cachedData;

      if (!cachedData) {
        const response = await this.axiosService
          .request()
          .get(`/bank/${id}/branches`);
        await this.cacheService.set(id, response);
      }
      return this.response.branches(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }

  async transferFees(data: TransferFees) {
    try {
      const response = await this.axiosService
        .request()
        .get(`/transfer/fee?currency${data.currency}&amount=${data.amount}`);

      return this.response.transferFees(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
  private async transferRate(data: TransferRate) {
    try {
      const response = await this.axiosService
        .request()
        .get(
          `/transfer/fee?currency${data.source_currency}&amount=${data.amount}`
        );

      return this.response.transferRate(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
  async transfer(data: Transfer) {
    try {
      const body = {
        ...data,
        reference: this.axiosService.generateUniqueId(this.type),
      };
      const response = await this.axiosService
        .request()
        .post(`/transfer/`, body);

      return this.response.transfer(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
  async transferBulk(data: TransferBulk) {
    try {
      const response = await this.axiosService
        .request()
        .post(`/transfer/`, data);

      return this.response.transfer(response, this.type);
    } catch (error) {
      this.axiosService.handleError(error);
    }
  }
}
