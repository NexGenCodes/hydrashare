import { Country, Reoccurrence } from "../../interface";
export type DataProvider = "MTN"|"GLO"|"AIRTEL"|"9MOBILE";
type Phone_number = string;
export enum DATA_BILLER_CODES {
  "MTN" = "BIL108",
  "GLO" = "BIL109",
  "AIRTEL" = "BIL110",
  "9MOBILE" = "BIL111",
}

export interface DataPurchase {
  customer: Phone_number;
  amount: number;
  country: Country;
  recurrence?: Reoccurrence;
  biller_name?: string;
  //   biller name == type
  type: string;
}

export interface DataPurchaseBulk {
  customers: DataPurchase;
  // an end point for receiving response on each completed purchase
  callback_url: string;
}

export interface VerifyDataNumber {
  customer: Phone_number;
  item_code: string;
  biller_code: string;
}
