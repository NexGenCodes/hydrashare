import { Country, Reoccurrence } from "../../interface";
export type BillerName =
  | "DSTV"
  | "MTN VTU"
  | "TIGO VTU"
  | "VODAFONE VTU"
  | "VODAFONE POSTPAID PAYMENT"
  | "AIRTEL VTU";

  type Phone_number = string;
export interface AirtimePurchase {
  customer: Phone_number;
  amount: number;
  country: Country;
  recurrence?: Reoccurrence;
  biller_name?: BillerName;
  // type == biller name
  type: BillerName;
}

export interface AirtimePurchaseBulk {
  customers: AirtimePurchase;
  // an end point for receiving response on each completed purchase
  callback_url: string;
}

export interface VerifyAirtimeNumber {
  customer: Phone_number;
  item_code: string;
  biller_code: string;
}
