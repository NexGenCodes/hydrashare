import { Country, Reoccurrence } from "../../interface";
export type ElectProvider = "IKEDC"|"EKEDC"|"EEDC";
type Meter_number= string;
export enum ELECT_BILLER_CODES{
  "IKEDC" = "BIL114",
  "EKEDC" = "BIL113",
  "EEDC" = "BIL115",
}
export interface ElectPurchase {
  customer: Meter_number;
  amount: number;
  country: Country;
  recurrence?: Reoccurrence;
  biller_name?: string;
  //   biller name == type
  type: string;
}

export interface ElectPurchaseBulk {
  customers: ElectPurchase;
  // an end point for receiving response on each completed purchase
  callback_url: string;
}

export interface   VerifyMeterNumber{
  customer: Meter_number;
  item_code: string;
  biller_code: string;
}


