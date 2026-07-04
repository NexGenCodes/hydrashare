import { Injectable } from "@nestjs/common";
import { AxiosResponse } from "axios";
import {
  Purchase,
  PurchaseBulk,
  Verify,
  Banks,
  Branches,
  Categories,
  TransferFees,
  Transfer,
  TransferRate,
  BillStatus
} from "./interface";
import { ServiceType } from "../interface";

@Injectable()
export default class ResponseService {
  purchase(response: AxiosResponse<Purchase>, type: ServiceType): Purchase {
    return { ...response.data, type };
  }
  purchaseBulk(
    response: AxiosResponse<PurchaseBulk>,
    type: ServiceType
  ): PurchaseBulk {
    return { ...response.data, type };
  }
  verify(response: AxiosResponse<Verify>, type: ServiceType): Verify {
    return { ...response.data, type };
  }
  banks(response: AxiosResponse<Banks>, type: ServiceType): Banks {
    return { ...response.data, type };
  }
  branches(response: AxiosResponse<Branches>, type: ServiceType): Branches {
    return { ...response.data, type };
  }
  categories(
    response: AxiosResponse<Categories>,
    type: ServiceType
  ): Categories {
    return { ...response.data, type };
  }
  transferFees(
    response: AxiosResponse<TransferFees>,
    type: ServiceType
  ): TransferFees {
    return { ...response.data, type };
  }
  transferRate(
    response: AxiosResponse<TransferRate>,
    type: ServiceType
  ): TransferRate {
    return { ...response.data, type };
  }
  transfer(response: AxiosResponse<Transfer>, type: ServiceType): Transfer {
    return { ...response.data, type };
  }
  billStatus(response: AxiosResponse<BillStatus>, type: ServiceType): BillStatus {
    return { ...response.data, type };
  }
}
