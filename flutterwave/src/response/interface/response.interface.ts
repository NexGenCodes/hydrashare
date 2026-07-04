import { ServiceType } from "../../interface";

interface Bank {
  id: string;
  code: string;
  name: string;
}

interface Branch {
  id: string;
  branch_code: string;
  branch_: string;
}

interface CategoryData {
  id: number;
  biller_code: string;
  name: string;
  default_commission: number;
  date_added: Date;
  country: string;
  is_airtime: boolean;
  biller_name: string;
  item_code: string;
  short_name: string;
  fee: number;
  commission_on_fee: boolean;
  label_name: string;
  amount: number;
}
export interface Categories {
  status: string;
  message: string;
  data: CategoryData[];
  type: ServiceType;
}
export interface Verify {
  status: string;
  message: string;
  data: {
    response_code: string;
    name: string;
    product_code: string;
    customer: string;
    biller_code?: string;
    amount: number;
    country: string;
  };
  type: ServiceType;
}
export interface Purchase {
  status: string;
  message: string;
  data: {
    phone_number: string;
    amount: string;
    flw_ref: string;
    tx_ref: string;
    reference?: string;
  };
  type: ServiceType;
}
export interface Status {
  status: string;
  message: string;
  data: {
    fee: number;
    amount: number;
    flw_ref: string;
    tx_ref: string;
    token?: string;
    extra?: string;
    currency?: string;
  };
  type: ServiceType;
}
export interface PurchaseBulk {
  status: string;
  message: string;
  data: {
    batch_reference: string | null;
  };
  type: ServiceType;
}
export interface Banks {
  status: string;
  message: string;
  data: Bank[];
  type: ServiceType;
}
export interface Branches {
  status: string;
  message: string;
  data: Branch[];
  type: ServiceType;
}

export interface Transfer{
  status: string;
  message: string;
  meta: {
    authorization:{
      transfer_reference:string;
      transfer_account:string;
    }
  };
  type: ServiceType;
}

export interface TransferRate{}

export interface TransferFees{}

export interface BillStatus{}
