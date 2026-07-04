import { Currency } from "../../interface";

export interface TransferFees{
amount:string;
currency:Currency;
type?:"mobilemoney"|"account"
}

interface Meta{
AccountNumber:string;
RoutingNumber:string;
BankName:string;
SwiftCode:string
}
export interface TransferRate{
amount:string;
destination_currency:Currency;
source_currency:Currency;
}

export interface Transfer{
    account_bank:string;
    account_number:string;
    amount:number;
    narration:string;
    currency:Currency;
    debit_subaccount?:string;
    beneficiary_name?:string;
    debit_currency:Currency;
    destination_branch_code:string;
    meta?:Meta[]
}
export interface TransferBulk{
   title:string;
   bulk_data:Transfer[];

}