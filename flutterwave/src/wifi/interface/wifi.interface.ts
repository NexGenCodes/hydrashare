import { Country, Reoccurrence } from "../../interface";
export type WifiProvider = "SWIFT" | "SPECTRANET" | "SMILE";
type phone_number = string;
export enum WIFI_BILLER_CODES {
  "SWIFT" = "BIL119",
  "SPECTRANET" = "BIL118",
  "SMILE" = "BIL118",
}
export interface WifiPurchase {
  customer: phone_number;
  amount: number;
  country: Country;
  recurrence?: Reoccurrence;
  biller_name?: string;
  //   biller name == type
  type: string;
}

export interface WifiPurchaseBulk {
  customers: WifiPurchase;
  // an end point for receiving response on each completed purchase
  callback_url: string;
}

export interface VerifyWifiNumber {
  customer: phone_number;
  item_code: string;
  biller_code: string;
}
