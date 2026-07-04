import { Country, Reoccurrence } from "../../interface";

export interface TollPurchase {
  customer: string;
  amount: number;
  country: Country;
  recurrence?: Reoccurrence;
  biller_name?: string;
  // type == biller name
  type: string;
}

export interface TollPurchaseBulk {
  customers: TollPurchase;
  // an end point for receiving response on each completed purchase
  callback_url: string;
}

export interface VerifyTollNumber {
  customer: string;
  item_code: string;
  biller_code: string;
}
