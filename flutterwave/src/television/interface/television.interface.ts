import { Country, Reoccurrence } from "../../interface";
export type TvProvider = "STARTIMES" | "DSTV" | "GOTV" | "SHOWMAX";
type smart_card_number = string;
type decoder_number = string;
export enum TV_BILLER_CODES {
  "DSTV" = "BIL119",
  "STARTIMES" = "BIL118",
  "GOTV" = "BIL118",
  "SHOWMAX" = "BIL118",
}
export interface TvPurchase {
  customer: smart_card_number | decoder_number;
  amount: number;
  country: Country;
  recurrence?: Reoccurrence;
  biller_name?: string;
  //   biller name == type
  type: string;
}

export interface TvPurchaseBulk {
  customers: TvPurchase;
  // an end point for receiving response on each completed purchase
  callback_url: string;
}

export interface VerifyTvNumber {
  customer: smart_card_number | decoder_number;
  item_code: string;
  biller_code: string;
}
